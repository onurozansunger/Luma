import Foundation
import Darwin

public enum DiscordLaunchConfiguration {
    public static func isConfigured(pid: pid_t) -> Bool? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size > 4, size <= 4 * 1024 * 1024 else { return nil }
        var bytes = [UInt8](repeating:0,count:size)
        let result = bytes.withUnsafeMutableBytes { sysctl(&mib, UInt32(mib.count), $0.baseAddress, &size, nil, 0) }
        guard result == 0 else { return nil }
        return parse(Array(bytes.prefix(size)))
    }

    // KERN_PROCARGS2: argc, executable path, padding, argv, environment.
    static func parse(_ bytes: [UInt8]) -> Bool? {
        guard bytes.count > 4 else { return nil }
        let argc = bytes.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
        guard argc > 0, argc < 4096 else { return nil }
        var cursor = 4
        func next() -> String? {
            guard cursor < bytes.count, let end = bytes[cursor...].firstIndex(of:0) else { return nil }
            let value = String(bytes:bytes[cursor..<end],encoding:.utf8)
            cursor = end + 1
            return value
        }
        guard next() != nil else { return nil }
        while cursor < bytes.count && bytes[cursor] == 0 { cursor += 1 }
        var arguments: [String] = []
        for _ in 0..<argc { guard let value = next() else { return nil }; arguments.append(value) }
        var environment: [String:String] = [:]
        while cursor < bytes.count {
            guard let entry = next() else { break }
            if let split = entry.firstIndex(of:"=") {
                let key = String(entry[..<split])
                // Keep only proxy settings; do not retain other environment values.
                if ["HTTPS_PROXY","HTTP_PROXY","https_proxy","http_proxy"].contains(key) {
                    environment[key] = String(entry[entry.index(after:split)...])
                }
            }
        }
        let http = "http://127.0.0.1:\(Product.httpPort)"
        return arguments.contains("--proxy-server=socks5://127.0.0.1:\(Product.socksPort)") &&
            ["HTTPS_PROXY","HTTP_PROXY","https_proxy","http_proxy"].allSatisfy { environment[$0] == http }
    }
}
