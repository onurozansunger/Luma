#!/usr/bin/env python3
"""Verify launchd recovery after supervisor SIGKILL. Never touches privileged services."""
import os,pathlib,plistlib,re,signal,socket,subprocess,sys,tempfile,time,json
app=pathlib.Path(sys.argv[1]).resolve()
label='app.luma.integration.'+str(os.getpid());domain=f'gui/{os.getuid()}';job=f'{domain}/{label}'
def run(*args): return subprocess.run(args,capture_output=True,text=True)
def healthy():
    try:
        with socket.create_connection(('127.0.0.1',17881),timeout=1) as s:
            s.sendall(b'\x05\x01\x00');return s.recv(2)==b'\x05\x00'
    except OSError:return False
def pid():
    r=run('/bin/launchctl','print',job);m=re.search(r'^\s*pid = (\d+)$',r.stdout,re.M)
    return int(m[1]) if m else None
def wait(predicate,seconds=20):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if predicate():return
        time.sleep(.15)
    raise AssertionError('Supervisor recovery timed out')
for port in (17881,17882):
    with socket.socket() as s:assert s.connect_ex(('127.0.0.1',port))!=0,'Stop app engine first'
with tempfile.TemporaryDirectory(prefix='luma-supervisor-test-') as temp:
    plist=pathlib.Path(temp)/'test.plist'
    plist.write_bytes(plistlib.dumps({'Label':label,'ProgramArguments':[str(app/'Contents/Resources/bin/LumaAgent')],'KeepAlive':True,'RunAtLoad':True,'ThrottleInterval':2,'ProcessType':'Background'}))
    r=run('/bin/launchctl','bootstrap',domain,str(plist));assert r.returncode==0,r.stderr
    try:
        wait(lambda:pid() is not None and healthy());first=pid()
        old_child=int(run('/usr/bin/pgrep','-P',str(first),'-x','ciadpi').stdout.strip())
        os.kill(first,signal.SIGKILL)
        wait(lambda:pid() not in (None,first) and run('/usr/bin/pgrep','-P',str(pid()),'-x','ciadpi').returncode==0 and healthy())
        wait(lambda:run('/bin/ps','-p',str(old_child),'-o','comm=').returncode!=0)
    finally:
        r=run('/bin/launchctl','bootout',job);assert r.returncode==0,r.stderr
    wait(lambda:not healthy(),8)
print(json.dumps({'status':'passed','checks':['Supervisor SIGKILL recovery','No orphan engine','LaunchAgent cleanup'],'scope':'temporary user LaunchAgent only'},indent=2))
