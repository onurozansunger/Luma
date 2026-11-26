import Foundation
import ServiceManagement
import Security
import CryptoKit
import Darwin
import LumaCore

let executable = Executable.currentURL()
let appBundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let tools = appBundle.appendingPathComponent("Contents/Resources/bin")
let rootDirectory = URL(fileURLWithPath:"/var/run/app.luma.gateway",isDirectory:true)

func requirement(for url: URL) throws -> String {
    var code: SecStaticCode?; var rule: SecRequirement?; var text: CFString?
    guard SecStaticCodeCreateWithPath(url as CFURL,SecCSFlags(),&code) == errSecSuccess, let code,
          SecStaticCodeCheckValidity(code,SecCSFlags(rawValue:kSecCSStrictValidate),nil) == errSecSuccess,
          SecCodeCopyDesignatedRequirement(code,SecCSFlags(),&rule) == errSecSuccess, let rule,
          SecRequirementCopyString(rule,SecCSFlags(),&text) == errSecSuccess, let text else { throw AppFailure("Uygulamanın imzası doğrulanamadı.") }
    return text as String
}
final class GatewayEngine {
    let queue = DispatchQueue(label:"app.luma.gateway.engine")
    var current = GatewayStatus()
    var owner: uid_t?
    var tunnel: ManagedChild?
    var awake: Process?
    var token: String?
    var oldForward: String?
    var oldRedirect: String?
    var network: NetworkSnapshot?
    var rulesLoaded = false
    var timer: DispatchSourceTimer?
    var failures = 0
    var lastHeartbeat = Date()
    var initializationError: String?
    init() {
        do {
            var statbuf = stat()
            if lstat(rootDirectory.path,&statbuf) == 0 {
                guard statbuf.st_uid == 0, statbuf.st_mode & S_IFMT == S_IFDIR, statbuf.st_mode & 0o022 == 0 else { throw AppFailure("Güvenli durum klasörü doğrulanamadı.") }
            } else { try FileManager.default.createDirectory(at:rootDirectory,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700]) }
            // A previous helper crash may leave our PF anchor behind. Restore only our saved state.
            let saved = rootDirectory.appendingPathComponent("recovery.json")
            if let d = try? Data(contentsOf:saved), let s = try? JSONDecoder().decode(Recovery.self,from:d) {
                token = s.token; oldForward = s.forward; oldRedirect = s.redirect; rulesLoaded = s.loaded
                cleanup(); if !current.running { current.message = "Önceki oturumun geçici ağ ayarları temizlendi." }
            }
        } catch { initializationError = error.localizedDescription; current.message = error.localizedDescription }
    }
    struct Recovery: Codable { var token: String?; var forward: String?; var redirect: String?; var loaded: Bool }
    func saveRecovery() throws {
        let data = try JSONEncoder().encode(Recovery(token:token,forward:oldForward,redirect:oldRedirect,loaded:rulesLoaded))
        try data.write(to:rootDirectory.appendingPathComponent("recovery.json"),options:.atomic)
    }
    func start(_ request: GatewayRequest, uid: uid_t) throws {
        if let initializationError { throw AppFailure(initializationError) }
        guard !current.running else { throw AppFailure("Bir paylaşım oturumu zaten açık.") }
        let found = try NetworkSnapshot.detect()
        guard found == request.expectedNetwork else { throw AppFailure("Ağ bağlantısı değişti. Adresleri yenileyip tekrar dene.") }
        try found.validateClient(request.client)
        guard SocketIO.socksHealthy(Product.socksPort) else { throw AppFailure("Önce bağlantı motorunu başlat.") }
        let filter = try Command.checked("/sbin/pfctl",["-sr"]), nat = try Command.checked("/sbin/pfctl",["-sn"])
        guard filter.contains("anchor \"com.apple/*\""), nat.contains("nat-anchor \"com.apple/*\"") else { throw AppFailure("macOS ağ filtrelerinin standart bağlantı noktası bulunamadı. Diğer kurallar değiştirilmedi.") }
        let existing = try Command.checked("/sbin/pfctl",["-a",PFPlan.anchor,"-sr"])
        guard !existing.contains("pass ") else { throw AppFailure("Önceki Luma oturumunu kapatıp tekrar dene.") }
        // Copy bytes before validating, then execute only this root-owned immutable copy.
        let bundledTunnel = tools.appendingPathComponent("tun2socks")
        let tunnelBytes = try Data(contentsOf:bundledTunnel)
        let digest = SHA256.hash(data:tunnelBytes).map { String(format:"%02x",$0) }.joined()
        guard !trustedTunnelSHA256.isEmpty, digest == trustedTunnelSHA256 else { throw AppFailure("Paylaşım motoru bu uygulama sürümüyle eşleşmiyor. Paketi yeniden derle veya yükle.") }
        let tunPath = rootDirectory.appendingPathComponent("tun2socks")
        try tunnelBytes.write(to:tunPath,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:tunPath.path)
        _ = try requirement(for:tunPath)
        let interface = (180...199).map { "utun\($0)" }.first { (try? Command.run("/sbin/ifconfig",[$0]).status) != 0 }
        guard let interface else { throw AppFailure("Boş bir sanal ağ arayüzü bulunamadı.") }
        owner = uid; network = found; oldForward = try Command.checked("/usr/sbin/sysctl",["-n","net.inet.ip.forwarding"]).trimmingCharacters(in:.whitespacesAndNewlines); oldRedirect = try Command.checked("/usr/sbin/sysctl",["-n","net.inet.ip.redirect"]).trimmingCharacters(in:.whitespacesAndNewlines)
        try saveRecovery()
        do {
            let p = try ManagedChild(executable:tunPath.path,arguments:["--device",interface,"--proxy","socks5://127.0.0.1:\(Product.socksPort)","--loglevel","silent","--udp-timeout","2m"])
            tunnel = p
            var ready = false
            for _ in 0..<50 {
                if !p.isRunning { break }
                if try Command.run("/sbin/ifconfig",[interface]).status == 0 { ready = true; break }
                Thread.sleep(forTimeInterval:0.1)
            }
            guard ready else { throw AppFailure("Paylaşım tüneli başlatılamadı.") }
            _ = try Command.checked("/sbin/ifconfig",[interface,"inet","198.18.0.1","198.18.0.1","netmask","255.255.255.255","mtu","1500","up"])
            let rules = try PFPlan.rules(client:request.client,network:found,tunnel:interface,tunnelIP:"198.18.0.1")
            let file = rootDirectory.appendingPathComponent("rules.conf"); try rules.write(to:file,atomically:true,encoding:.utf8)
            _ = try Command.checked("/sbin/pfctl",["-n","-a",PFPlan.anchor,"-f",file.path])
            rulesLoaded = true; try saveRecovery()
            _ = try Command.checked("/sbin/pfctl",["-a",PFPlan.anchor,"-f",file.path])
            let enabled = try Command.checked("/sbin/pfctl",["-E"])
            let regex = try NSRegularExpression(pattern:"Token\\s*:\\s*(\\d+)")
            if let match = regex.firstMatch(in:enabled,range:NSRange(enabled.startIndex...,in:enabled)), let r = Range(match.range(at:1),in:enabled) { token = String(enabled[r]) }
            guard token != nil else { throw AppFailure("Ağ filtresi oturum anahtarı alınamadı.") }
            try saveRecovery()
            _ = try Command.checked("/usr/sbin/sysctl",["-w","net.inet.ip.redirect=0"])
            _ = try Command.checked("/usr/sbin/sysctl",["-w","net.inet.ip.forwarding=1"])
            let awake = Process(); awake.executableURL = URL(fileURLWithPath:"/usr/bin/caffeinate"); awake.arguments = ["-i","-w",String(p.processIdentifier)]; try awake.run(); self.awake = awake
            current = GatewayStatus(running:true,client:request.client,message:"PS5 paylaşımı açık",startedAt:Date()); lastHeartbeat = Date(); failures = 0
            let monitor = DispatchSource.makeTimerSource(queue:queue); monitor.schedule(deadline:.now()+3,repeating:3)
            monitor.setEventHandler { [weak self] in self?.checkHealth() }; monitor.resume(); timer = monitor
        } catch { cleanup(); throw error }
    }
    func checkHealth() {
        guard current.running else { return }
        let healthy = tunnel?.isRunning == true && SocketIO.socksHealthy(Product.socksPort) && (try? NetworkSnapshot.detect()) == network
        failures = healthy ? 0 : failures+1
        if failures >= 3 || Date().timeIntervalSince(lastHeartbeat) > 25 {
            cleanup(); if !current.running { current.message = "Bağlantı kesildi; geçici ağ ayarları geri alındı. PS5’i normal profiline alabilirsin." }
        }
    }
    func cleanup() {
        timer?.cancel(); timer = nil
        var problems: [String] = []
        func restore(_ path: String, _ arguments: [String]) -> Bool {
            do { _ = try Command.checked(path,arguments); return true }
            catch { problems.append(error.localizedDescription); return false }
        }
        if rulesLoaded, restore("/sbin/pfctl",["-a",PFPlan.anchor,"-F","all"]) { rulesLoaded = false }
        if let v = oldForward, ["0","1"].contains(v), restore("/usr/sbin/sysctl",["-w","net.inet.ip.forwarding=\(v)"]) { oldForward = nil }
        if let v = oldRedirect, ["0","1"].contains(v), restore("/usr/sbin/sysctl",["-w","net.inet.ip.redirect=\(v)"]) { oldRedirect = nil }
        if let value = token, !value.isEmpty, value.allSatisfy(\.isNumber), restore("/sbin/pfctl",["-X",value]) { token = nil }
        tunnel?.stop()
        if let p = awake, p.isRunning { p.terminate() }
        tunnel = nil; awake = nil
        if problems.isEmpty {
            owner = nil; current = GatewayStatus()
            try? FileManager.default.removeItem(at:rootDirectory.appendingPathComponent("recovery.json"))
        } else {
            // Retain recovery state and allow another stop attempt instead of reporting success.
            current.running = true
            current.message = "Ağ ayarları tamamen geri alınamadı. PS5’i normal profiline alıp tekrar Durdur’a bas. " + problems.joined(separator:"; ")
            try? saveRecovery()
        }
    }
}
guard geteuid() == 0 else { fputs("This helper is managed by macOS ServiceManagement.\n",stderr); exit(1) }
let engine = GatewayEngine()
final class Session: NSObject, GatewayServiceProtocol {
    let uid: uid_t
    init(uid:uid_t) { self.uid = uid }
    func respond(_ reply: @escaping (Data)->Void) { reply((try? JSONEncoder().encode(engine.current)) ?? Data()) }
    func start(_ request: Data, reply: @escaping (Data)->Void) {
        engine.queue.async { [self] in
            do { guard request.count < 4096 else { throw AppFailure("Geçersiz istek.") }; try engine.start(JSONDecoder().decode(GatewayRequest.self,from:request),uid:uid) }
            catch { if !engine.current.running { engine.current.message = error.localizedDescription } }
            respond(reply)
        }
    }
    func stop(reply: @escaping (Data)->Void) { engine.queue.async { [self] in if engine.owner == nil || engine.owner == uid { engine.cleanup() }; respond(reply) } }
    func status(reply: @escaping (Data)->Void) { engine.queue.async { [self] in if engine.owner == uid { engine.lastHeartbeat = Date() }; respond(reply) } }
}
final class Delegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener:NSXPCListener,shouldAcceptNewConnection connection:NSXPCConnection)->Bool {
        guard connection.effectiveUserIdentifier != 0 else { return false }
        connection.exportedInterface = NSXPCInterface(with:GatewayServiceProtocol.self)
        connection.exportedObject = Session(uid:connection.effectiveUserIdentifier)
        connection.resume(); return true
    }
}
let delegate = Delegate(); let listener = NSXPCListener(machServiceName:Product.gatewayID)
do { listener.setConnectionCodeSigningRequirement(try requirement(for:appBundle)) } catch { fputs("Code-signing verification failed.\n",stderr); exit(1) }
listener.delegate = delegate; listener.resume()
signal(SIGTERM,SIG_IGN)
let stopSource = DispatchSource.makeSignalSource(signal:SIGTERM,queue:engine.queue)
stopSource.setEventHandler { engine.cleanup(); exit(0) }; stopSource.resume()
RunLoop.current.run()
