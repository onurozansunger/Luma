import Foundation
import Darwin

public enum SocketIO {
    public static func close(_ fd: Int32) { if fd >= 0 { _ = Darwin.close(fd) } }
    public static func configure(_ fd: Int32, seconds: Int = 12) {
        _ = fcntl(fd,F_SETFD,FD_CLOEXEC)
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
        var timeout = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    }
    public static func connectLocal(_ port: Int, seconds: Int = 3) throws -> Int32 {
        guard (1024...65535).contains(port) else { throw AppFailure("Geçersiz bağlantı noktası.") }
        let fd = socket(AF_INET, SOCK_STREAM, 0); guard fd >= 0 else { throw AppFailure("Soket açılamadı.") }
        configure(fd, seconds: seconds)
        var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET); address.sin_port = UInt16(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard result == 0 else { close(fd); throw AppFailure("Yerel bağlantı motoru yanıt vermiyor.") }
        return fd
    }
    public static func available(_ port: Int) -> Bool { guard let fd = try? connectLocal(port, seconds: 1) else { return false }; close(fd); return true }
    public static func read(_ fd: Int32, count: Int) throws -> [UInt8] {
        var result = [UInt8](repeating: 0, count: count); var offset = 0
        while offset < count {
            let n = result.withUnsafeMutableBytes { recv(fd, $0.baseAddress!.advanced(by: offset), count-offset, 0) }
            guard n > 0 else { throw AppFailure("Bağlantı kapandı veya zaman aşımına uğradı.") }; offset += n
        }; return result
    }
    public static func write(_ fd: Int32, _ bytes: [UInt8]) throws {
        var offset = 0
        while offset < bytes.count {
            let n = bytes.withUnsafeBytes { send(fd, $0.baseAddress!.advanced(by: offset), bytes.count-offset, 0) }
            guard n > 0 else { throw AppFailure("Bağlantıya veri yazılamadı.") }; offset += n
        }
    }
    public static func socksConnect(port: Int, host: String, destinationPort: UInt16) throws -> Int32 {
        // The SOCKS reply arrives only after the engine reaches the remote host;
        // a 3 s timeout drops slow but healthy connections with a 502.
        let fd = try connectLocal(port, seconds: 12)
        do {
            try write(fd, [5,1,0]); guard try read(fd,count: 2) == [5,0] else { throw AppFailure("SOCKS el sıkışması başarısız.") }
            let domain = Array(host.utf8); guard !domain.isEmpty, domain.count <= 255 else { throw AppFailure("Geçersiz sunucu adı.") }
            try write(fd,[5,1,0,3,UInt8(domain.count)] + domain + [UInt8(destinationPort >> 8),UInt8(destinationPort & 255)])
            let header = try read(fd,count: 4); guard header[0] == 5, header[1] == 0, header[2] == 0 else { throw AppFailure("Uzak sunucuya bağlanılamadı.") }
            let n: Int
            switch header[3] { case 1: n = 4; case 4: n = 16; case 3: n = Int(try read(fd,count: 1)[0]); default: throw AppFailure("Geçersiz SOCKS yanıtı.") }
            _ = try read(fd,count: n+2); return fd
        } catch { close(fd); throw error }
    }
    public static func socksHealthy(_ port: Int) -> Bool {
        guard let fd = try? connectLocal(port,seconds: 1) else { return false }; defer { close(fd) }
        do { try write(fd,[5,1,0]); return try read(fd,count: 2) == [5,0] } catch { return false }
    }
}
public struct ConnectTarget: Equatable {
    public let host: String; public let port: UInt16
    public static func parse(_ header: String) throws -> ConnectTarget {
        guard header.utf8.count <= 16_384, header.hasSuffix("\r\n\r\n"), !header.contains("\0"), let line = header.components(separatedBy: "\r\n").first else { throw AppFailure("Geçersiz proxy isteği.") }
        let parts = line.split(separator: " ")
        guard parts.count == 3, parts[0] == "CONNECT", ["HTTP/1.0","HTTP/1.1"].contains(String(parts[2])), let colon = parts[1].lastIndex(of: ":"), let port = UInt16(parts[1][parts[1].index(after: colon)...]), port == 443 else { throw AppFailure("Yalnızca HTTPS CONNECT desteklenir.") }
        let host = String(parts[1][..<colon]); guard host.range(of: "^[A-Za-z0-9][A-Za-z0-9.\\-]{0,252}$", options: .regularExpression) != nil else { throw AppFailure("Geçersiz sunucu adı.") }
        let labels = host.split(separator:".",omittingEmptySubsequences:false)
        guard labels.allSatisfy({ !$0.isEmpty && $0.count <= 63 && !$0.hasPrefix("-") && !$0.hasSuffix("-") }) else { throw AppFailure("Geçersiz sunucu adı.") }
        return ConnectTarget(host: host, port: port)
    }
}
public final class HTTPBridge {
    private var listener: Int32 = -1
    private let limit = DispatchSemaphore(value: 64)
    private let socksPort: Int
    public init(socksPort: Int) { self.socksPort = socksPort }
    public func listen(port: Int) throws {
        listener = socket(AF_INET, SOCK_STREAM, 0); guard listener >= 0 else { throw AppFailure("Proxy başlatılamadı.") }
        _ = fcntl(listener,F_SETFD,FD_CLOEXEC)
        var reuse: Int32 = 1; setsockopt(listener,SOL_SOCKET,SO_REUSEADDR,&reuse,socklen_t(MemoryLayout<Int32>.size))
        var a = sockaddr_in(); a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); a.sin_family = sa_family_t(AF_INET); a.sin_port = UInt16(port).bigEndian; a.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self,capacity: 1) { bind(listener,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0, Darwin.listen(listener,32) == 0 else { SocketIO.close(listener); listener = -1; throw AppFailure("Yerel proxy portu başka bir uygulamada kullanılıyor.") }
        let listeningFD = listener
        DispatchQueue.global(qos: .utility).async { [self] in
            while true {
                let fd = accept(listeningFD,nil,nil)
                if fd < 0 { return }
                _ = fcntl(fd,F_SETFD,FD_CLOEXEC)
                guard limit.wait(timeout: .now()) == .success else { SocketIO.close(fd); continue }
                DispatchQueue.global(qos: .utility).async { [self] in defer { limit.signal() }; handle(fd) }
            }
        }
    }
    public func stop() { let fd = listener; listener = -1; if fd >= 0 { shutdown(fd,SHUT_RDWR); SocketIO.close(fd) } }
    private func handle(_ client: Int32) {
        defer { SocketIO.close(client) }; SocketIO.configure(client)
        var upstream: Int32 = -1; defer { SocketIO.close(upstream) }
        do {
            var header = [UInt8](); let delimiter: [UInt8] = [13,10,13,10]
            let headerDeadline = Date().addingTimeInterval(12)
            while !header.suffix(4).elementsEqual(delimiter) {
                guard Date() < headerDeadline else { throw AppFailure("Proxy başlığı zaman aşımına uğradı.") }
                guard header.count < 16_384 else { throw AppFailure("Başlık çok uzun.") }
                header += try SocketIO.read(client,count: 1)
            }
            let target = try ConnectTarget.parse(String(decoding: header,as: UTF8.self))
            upstream = try SocketIO.socksConnect(port: socksPort,host: target.host,destinationPort: target.port)
            try SocketIO.write(client,Array("HTTP/1.1 200 Connection Established\r\n\r\n".utf8))
            var fds = [pollfd(fd:client,events:Int16(POLLIN),revents:0),pollfd(fd:upstream,events:Int16(POLLIN),revents:0)]
            var buffer = [UInt8](repeating:0,count:65536)
            while true {
                let ready = poll(&fds,2,120_000); guard ready > 0 else { return }
                for i in 0...1 where fds[i].revents != 0 {
                    let n = recv(fds[i].fd,&buffer,buffer.count,0); guard n > 0 else { return }
                    try SocketIO.write(fds[1-i].fd,Array(buffer.prefix(n)))
                }
            }
        } catch { if upstream < 0 { try? SocketIO.write(client,Array("HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n".utf8)) } }
    }
}
