import Foundation
import Darwin
import MachO

public enum Executable {
    public static func currentURL() -> URL {
        var count: UInt32 = 0
        _NSGetExecutablePath(nil,&count)
        var buffer = [CChar](repeating:0,count:Int(count))
        precondition(_NSGetExecutablePath(&buffer,&count) == 0)
        return URL(fileURLWithPath:String(cString:buffer)).resolvingSymlinksInPath()
    }
}
public enum Product {
    #if arch(arm64)
    public static let architecture = "arm64"
    #else
    public static let architecture = "x64"
    #endif
    public static let version = "0.2.5"
    public static let appID = "app.luma.mac"
    public static let agentID = "app.luma.agent"
    public static let gatewayID = "app.luma.gateway"
    public static let socksPort = 17881
    public static let httpPort = 17882
    public static var support: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Luma", isDirectory: true) }
    public static var logs: URL { support.appendingPathComponent("Logs", isDirectory: true) }
}
public struct AppFailure: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
public struct CommandResult {
    public let status: Int32
    public let text: String
}
public enum Command {
    // No shell interpolation. All executables and argument arrays are explicit.
    public static func run(_ path: String, _ args: [String] = [], timeout: TimeInterval = 8) throws -> CommandResult {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        p.environment = ["PATH":"/usr/bin:/bin:/usr/sbin:/sbin","LC_ALL":"C"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        try p.run()
        let output = NSMutableData(); let group = DispatchGroup(); group.enter()
        DispatchQueue.global().async { output.append(pipe.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.03) }
        if p.isRunning { p.terminate(); Thread.sleep(forTimeInterval: 0.1); if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
        p.waitUntilExit(); group.wait()
        return CommandResult(status: p.terminationStatus, text: String(data: output as Data, encoding: .utf8) ?? "")
    }
    public static func checked(_ path: String, _ args: [String] = []) throws -> String {
        let r = try run(path, args)
        guard r.status == 0 else { throw AppFailure("\(URL(fileURLWithPath: path).lastPathComponent): \(r.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))") }
        return r.text
    }
}
public struct IPv4: Equatable, Codable, CustomStringConvertible {
    public let value: UInt32
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var result: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), part.count <= 3,
                  let byte = UInt8(part), part == "0" || !part.hasPrefix("0") else { return nil }
            result = (result << 8) | UInt32(byte)
        }
        value = result
    }
    public init(value: UInt32) { self.value = value }
    public var description: String { [24,16,8,0].map { String((value >> $0) & 255) }.joined(separator: ".") }
    public var isPrivate: Bool { (value >> 24 == 10) || (value >> 20 == 0xac1) || (value >> 16 == 0xc0a8) }
    public static func validMask(_ mask: IPv4) -> Bool { let inverse = ~mask.value; return mask.value != 0 && inverse & (inverse &+ 1) == 0 }
}
public struct NetworkSnapshot: Codable, Equatable {
    public var interface: String
    public var address: String
    public var mask: String
    public var router: String
    public var isWiFi: Bool { interface.hasPrefix("en") }
    public init(interface: String, address: String, mask: String, router: String) { self.interface = interface; self.address = address; self.mask = mask; self.router = router }
    public static func detect() throws -> NetworkSnapshot {
        let route = try Command.checked("/sbin/route", ["-n","get","default"])
        func field(_ key: String) -> String { route.split(separator: "\n").first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(key + ":") }?.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "" }
        let name = field("interface"), gateway = field("gateway")
        guard !name.isEmpty, IPv4(gateway) != nil else { throw AppFailure("Etkin bir IPv4 ağ bağlantısı bulunamadı.") }
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { throw AppFailure("Ağ arayüzleri okunamadı.") }
        defer { freeifaddrs(list) }
        var cursor = list
        while let current = cursor {
            let item = current.pointee; defer { cursor = item.ifa_next }
            guard String(cString: item.ifa_name) == name, let address = item.ifa_addr, address.pointee.sa_family == UInt8(AF_INET), let netmask = item.ifa_netmask else { continue }
            func string(_ p: UnsafeMutablePointer<sockaddr>) -> String {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(p, socklen_t(p.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                return String(cString: host)
            }
            return NetworkSnapshot(interface: name, address: string(address), mask: string(netmask), router: gateway)
        }
        throw AppFailure("Mac’in yerel IPv4 adresi bulunamadı.")
    }
    public var cidr: String {
        guard let ip = IPv4(address), let mask = IPv4(mask) else { return "" }
        return "\(IPv4(value: ip.value & mask.value))/\(mask.value.nonzeroBitCount)"
    }
    public func validateClient(_ text: String) throws {
        guard let client = IPv4(text), client.isPrivate, let local = IPv4(address), let m = IPv4(mask), IPv4.validMask(m) else { throw AppFailure("Konsolun yerel IPv4 adresini girin.") }
        guard client != local, text != router else { throw AppFailure("PS5 adresi Mac veya router adresiyle aynı olamaz.") }
        guard client.value & m.value == local.value & m.value else { throw AppFailure("PS5 ve Mac aynı yerel ağda olmalı.") }
        let host = client.value & ~m.value
        guard host != 0, host != ~m.value else { throw AppFailure("Bu adres bir cihaz adresi değil.") }
        guard interface.range(of: "^[a-z][a-z0-9]{0,14}$", options: .regularExpression) != nil else { throw AppFailure("Ağ arayüzü geçersiz.") }
    }
}
public enum ConnectionPreset: String, Codable, CaseIterable {
    case balanced, split, disorder, compatible
    public var title: String { switch self { case .balanced: return "Dengeli"; case .split: return "TLS bölme"; case .disorder: return "Alternatif"; case .compatible: return "Uyumlu TLS" } }
    public var detail: String { switch self { case .balanced: return "Önerilen başlangıç yöntemi."; case .split: return "Dengeli mod çalışmıyorsa farklı bir TLS yöntemi dener."; case .disorder: return "Farklı ağ filtreleri için alternatif paket sıralaması."; case .compatible: return "Discord güncelleyicisi TLS bağlantısında takılıyorsa bu yöntemi deneyin." } }
    public var arguments: [String] { switch self { case .balanced: return ["--disorder","1","--auto=torst","--tlsrec","1+s"]; case .split: return ["--split","1","--tlsrec","1+s"]; case .disorder: return ["--disorder","1"]; case .compatible: return ["--tlsrec","1"] } }
}
public struct GatewayRequest: Codable { public var client: String; public var expectedNetwork: NetworkSnapshot; public init(client: String, expectedNetwork: NetworkSnapshot) { self.client = client; self.expectedNetwork = expectedNetwork } }
public struct GatewayStatus: Codable {
    public var running: Bool; public var client: String; public var message: String; public var startedAt: Date?
    public init(running: Bool = false, client: String = "", message: String = "Paylaşım kapalı", startedAt: Date? = nil) { self.running = running; self.client = client; self.message = message; self.startedAt = startedAt }
}
@objc public protocol GatewayServiceProtocol {
    func start(_ request: Data, reply: @escaping (Data) -> Void)
    func stop(reply: @escaping (Data) -> Void)
    func status(reply: @escaping (Data) -> Void)
}
public enum PFPlan {
    public static let anchor = "com.apple/luma"
    public static func rules(client: String, network: NetworkSnapshot, tunnel: String, tunnelIP: String) throws -> String {
        try network.validateClient(client)
        guard tunnel.range(of: "^utun[0-9]{1,5}$", options: .regularExpression) != nil, IPv4(tunnelIP) != nil else { throw AppFailure("Geçersiz tünel ayarı.") }
        return """
        # Luma: scoped to the selected client only.
        nat on \(network.interface) inet from \(client) to ! \(network.cidr) -> (\(network.interface))
        pass in quick on \(network.interface) route-to (\(tunnel) \(tunnelIP)) inet proto { tcp udp } from \(client) to ! \(network.cidr) keep state

        """
    }
}
