#!/usr/bin/env python3
"""Isolated user-space integration test. Does not touch PF, sysctls or other running services."""
import json, os, pathlib, secrets, signal, socket, struct, subprocess, sys, time

bundle = pathlib.Path(sys.argv[1]).resolve()
agent = bundle / 'Contents/Resources/bin/LumaAgent'
SOCKS, HTTP = 17881, 17882

def recv_n(s, n):
    data = b''
    while len(data) < n:
        part = s.recv(n-len(data))
        if not part: raise RuntimeError('connection closed')
        data += part
    return data

def healthy():
    try:
        with socket.create_connection(('127.0.0.1', SOCKS), timeout=1) as s:
            s.sendall(b'\x05\x01\x00')
            return recv_n(s, 2) == b'\x05\x00'
    except OSError:
        return False

def wait_for(check, timeout=15):
    end = time.monotonic()+timeout
    while time.monotonic() < end:
        if check(): return
        time.sleep(.1)
    raise AssertionError('Timed out waiting for test condition')

for port in (SOCKS, HTTP):
    with socket.socket() as s:
        assert s.connect_ex(('127.0.0.1',port)) != 0, 'Close the new app engine before running this isolated test'
assert agent.is_file()
preset = sys.argv[2] if len(sys.argv) > 2 else 'balanced'
assert preset in ('balanced','split','disorder','compatible')
child = subprocess.Popen([str(agent),'--preset',preset], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
checks = []
try:
    wait_for(healthy)
    checks.append('SOCKS handshake')
    for name, url in [
        ('Discord HTTPS', 'https://discord.com/api/v10/gateway'),
        ('Updater HTTPS', 'https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=osx&arch=arm64')
    ]:
        r = subprocess.run(['/usr/bin/curl','--proxy',f'http://127.0.0.1:{HTTP}','--connect-timeout','4','--max-time','12','-sS','-o','/dev/null','-w','%{http_code}',url],capture_output=True,text=True,timeout=15)
        assert r.returncode == 0 and r.stdout == '200', (name,r.returncode,r.stdout)
        checks.append(name)
    if preset == 'compatible':
        r = subprocess.run(['/usr/bin/curl','--proxy',f'http://127.0.0.1:{HTTP}','--tls-max','1.2','--connect-timeout','4','--max-time','12','-sS','-o','/dev/null','-w','%{http_code}','https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=osx&arch=arm64'],capture_output=True,text=True,timeout=15)
        assert r.returncode == 0 and r.stdout == '200', ('Updater TLS 1.2',r.returncode,r.stdout)
        checks.append('Updater TLS 1.2 compatibility')
    with socket.create_connection(('127.0.0.1',SOCKS),timeout=5) as control:
        control.sendall(b'\x05\x01\x00'); assert recv_n(control,2) == b'\x05\x00'
        control.sendall(b'\x05\x03\x00\x01'+socket.inet_aton('127.0.0.1')+b'\x00\x00')
        head = recv_n(control,4); assert head[1] == 0 and head[3] == 1
        address = socket.inet_ntoa(recv_n(control,4)); port = struct.unpack('!H',recv_n(control,2))[0]
        if address == '0.0.0.0': address = '127.0.0.1'
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as udp:
            udp.settimeout(6)
            for server in ['1.1.1.1','1.0.0.1']:
                ident = secrets.randbits(16)
                query = struct.pack('!HHHHHH',ident,0x100,1,0,0,0)+b'\x07discord\x03com\x00'+struct.pack('!HH',1,1)
                udp.sendto(b'\0\0\0\x01'+socket.inet_aton(server)+struct.pack('!H',53)+query,(address,port))
                reply,_ = udp.recvfrom(4096)
                result = struct.unpack('!HHHHHH',reply[10:22]); assert result[0] == ident and result[3] > 0
                checks.append('SOCKS UDP DNS '+server)
    with socket.create_connection(('127.0.0.1',HTTP),timeout=3) as s:
        s.sendall(b'CONNECT example.com:22 HTTP/1.1\r\n\r\n')
        assert b'502' in s.recv(512)
    checks.append('Rejected non-HTTPS CONNECT')
    with socket.create_connection(('127.0.0.1',HTTP),timeout=3) as s:
        s.sendall(b'A'*16385)
        try: assert b'200' not in s.recv(512)
        except ConnectionResetError: pass
    checks.append('Header size limit')
    for sent_signal, label in [(signal.SIGTERM,'Graceful engine restart'),(signal.SIGKILL,'Engine child crash recovery')]:
        pids = subprocess.check_output(['/usr/bin/pgrep','-P',str(child.pid),'-x','ciadpi'],text=True).split()
        assert len(pids) == 1
        os.kill(int(pids[0]),sent_signal)
        def restarted():
            r = subprocess.run(['/usr/bin/pgrep','-P',str(child.pid),'-x','ciadpi'],capture_output=True,text=True)
            return r.returncode == 0 and r.stdout.strip() != pids[0] and healthy()
        wait_for(restarted)
        checks.append(label)

finally:
    child.terminate()
    try: child.wait(timeout=5)
    except subprocess.TimeoutExpired: child.kill();child.wait()
wait_for(lambda: not healthy(),5)
checks.append('Clean shutdown')
print(json.dumps({'status':'passed','checks':checks,'scope':'user-space only; privileged gateway untouched'},ensure_ascii=False,indent=2))
