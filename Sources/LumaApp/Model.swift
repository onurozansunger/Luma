import SwiftUI
import AppKit
import ServiceManagement
import Security
import LumaCore

struct HealthCheck: Identifiable {
    let id = UUID(); let title: String; var detail: String; var state: State
    enum State { case waiting, checking, good, failed }
}
enum Page: String, CaseIterable {
    case overview = "Genel bakış", console = "PS5 kurulumu", diagnostics = "Bağlantı kontrolü", settings = "Ayarlar", about = "Hakkında"
    var icon: String { switch self { case .overview:return "square.grid.2x2"; case .console:return "gamecontroller"; case .diagnostics:return "waveform.path.ecg"; case .settings:return "slider.horizontal.3"; case .about:return "info.circle" } }
}
@MainActor final class AppModel: ObservableObject {
    @Published var page: Page = .overview
    @Published var engineRunning = false
    @Published var gateway = GatewayStatus() { didSet { updateActivity() } }
    // The helper stops sharing when status heartbeats pause for 25 s. Without this,
    // App Nap can throttle the refresh timer while the window is hidden.
    private var activity: NSObjectProtocol?
    private func updateActivity() {
        if gateway.running, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options:[.userInitiatedAllowingIdleSystemSleep,.latencyCritical],reason:"PS5 paylaşımı açık")
        } else if !gateway.running, let current = activity {
            ProcessInfo.processInfo.endActivity(current);activity = nil
        }
    }
    @Published var network: NetworkSnapshot?
    @Published var clientIP: String = UserDefaults.standard.string(forKey:"clientIP") ?? "" { didSet { UserDefaults.standard.set(clientIP,forKey:"clientIP") } }
    @Published var preset: ConnectionPreset = ConnectionPreset(rawValue:UserDefaults.standard.string(forKey:"preset") ?? "balanced") ?? .balanced { didSet { UserDefaults.standard.set(preset.rawValue,forKey:"preset") } }
    @Published var busy = false
    @Published var testing = false
    @Published var error: String?
    @Published var notice: String?
    @Published var helperApproved = false
    @Published var helperNeedsApproval = false
    @Published var showStopEngine = false
    @Published var showReconnectDiscord = false
    @Published var lastChecked: Date?
    @Published var checks: [HealthCheck] = []
    @Published var autoStart = SMAppService.mainApp.status == .enabled
    @Published var maintainDiscord = UserDefaults.standard.object(forKey:"maintainDiscord") as? Bool ?? true {
        didSet { UserDefaults.standard.set(maintainDiscord,forKey:"maintainDiscord") }
    }
    private var discordInspected = Set<pid_t>()
    private var discordRepairs: [Date] = []
    private var discordInspectionPending = false
    private var timer: Timer?
    private var connection: NSXPCConnection?
    private var pendingGatewayAction: UUID?
    let helper = SMAppService.daemon(plistName:"app.luma.gateway.plist")
    var resources: URL { Bundle.main.resourceURL! }
    var agentPlist: URL { Product.support.appendingPathComponent("app.luma.agent.plist") }
    var canStartPS5: Bool { network != nil && validClient && !busy }
    var validClient: Bool { guard let network else { return false }; return (try? network.validateClient(clientIP)) != nil }
    var clientValidation: String? { guard !clientIP.isEmpty, let network else { return nil }; do { try network.validateClient(clientIP);return nil } catch { return error.localizedDescription } }
    init() {
        try? FileManager.default.createDirectory(at:Product.logs,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval:5,repeats:true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }
    func refresh() {
        helperApproved = helper.status == .enabled; helperNeedsApproval = helper.status == .requiresApproval
        Task { [self] in
            let result = await Task.detached { () -> (NetworkSnapshot?,Bool) in
                (try? NetworkSnapshot.detect(), SocketIO.socksHealthy(Product.socksPort) && SocketIO.available(Product.httpPort))
            }.value
            network = result.0; engineRunning = result.1
            maintainDiscordConnection()
            if helperApproved { proxy(reportErrors:false)?.status { [weak self] data in Task { @MainActor in self?.acceptStatus(data) } } }
        }
    }
    /// Background status polls pass `reportErrors: false` so a failed poll neither shows
    /// a banner every 5 s nor ends an in-flight start/stop action.
    private func proxy(reportErrors: Bool = true, onError: (@MainActor () -> Void)? = nil) -> GatewayServiceProtocol? {
        if connection == nil {
            let c = NSXPCConnection(machServiceName:Product.gatewayID,options:.privileged)
            c.remoteObjectInterface = NSXPCInterface(with:GatewayServiceProtocol.self)
            let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/HelperTools/LumaGateway")
            var code: SecStaticCode?;var req: SecRequirement?;var text: CFString?
            guard SecStaticCodeCreateWithPath(helperURL as CFURL,SecCSFlags(),&code) == errSecSuccess, let code,
                  SecCodeCopyDesignatedRequirement(code,SecCSFlags(),&req) == errSecSuccess, let req,
                  SecRequirementCopyString(req,SecCSFlags(),&text) == errSecSuccess, let text else { error = "Paylaşım yardımcısının imzası okunamadı.";return nil }
            c.setCodeSigningRequirement(text as String)
            c.invalidationHandler = { [weak self] in Task { @MainActor in self?.connection = nil } }
            c.interruptionHandler = { [weak self] in Task { @MainActor in self?.gateway = GatewayStatus(message:"Paylaşım yardımcısına bağlantı kesildi.") } }
            c.resume(); connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] e in Task { @MainActor in
            onError?()
            guard reportErrors else { return }
            self?.error = "Paylaşım yardımcısına ulaşılamadı: \(e.localizedDescription)";self?.endGatewayAction()
        } } as? GatewayServiceProtocol
    }
    private func acceptStatus(_ data: Data) { if let state = try? JSONDecoder().decode(GatewayStatus.self,from:data) { gateway = state } }
    private func prepareAgent() throws {
        let exe = resources.appendingPathComponent("bin/LumaAgent")
        guard FileManager.default.isExecutableFile(atPath:exe.path), FileManager.default.isExecutableFile(atPath:resources.appendingPathComponent("bin/ciadpi").path) else { throw AppFailure("Bağlantı motoru uygulama paketinde bulunamadı. Tam uygulama paketini kullan.") }
        let plist: [String:Any] = ["Label":Product.agentID,"ProgramArguments":[exe.path,"--preset",preset.rawValue],"RunAtLoad":true,"KeepAlive":true,"ThrottleInterval":3,"ProcessType":"Interactive","StandardOutPath":Product.logs.appendingPathComponent("agent.log").path,"StandardErrorPath":Product.logs.appendingPathComponent("agent-error.log").path]
        try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).write(to:agentPlist,options:.atomic)
    }
    private func startEngineWork() async throws {
        try prepareAgent();let plist = agentPlist.path
        let wanted = preset.rawValue
        try await Task.detached {
            let domain = "gui/\(getuid())";let job = "\(domain)/\(Product.agentID)"
            func loaded() throws -> Bool { try Command.run("/bin/launchctl",["print",job]).status == 0 }
            if try loaded() {
                // launchd keeps the plist from bootstrap time; kickstart would reuse stale arguments.
                let status = (try? Data(contentsOf:Product.support.appendingPathComponent("agent-status.json"))).flatMap { try? JSONSerialization.jsonObject(with:$0) as? [String:Any] }
                let healthy = SocketIO.socksHealthy(Product.socksPort) && SocketIO.available(Product.httpPort)
                if !healthy || (status?["preset"] as? String).map({ $0 != wanted }) == true {
                    _ = try? Command.run("/bin/launchctl",["bootout",job])
                    for _ in 0..<40 { if try !loaded() { break };try await Task.sleep(for:.milliseconds(100)) }
                }
            }
            if try !loaded() { _ = try Command.checked("/bin/launchctl",["bootstrap",domain,plist]) }
            for _ in 0..<60 { if SocketIO.socksHealthy(Product.socksPort) && SocketIO.available(Product.httpPort) { return };try await Task.sleep(for:.milliseconds(100)) }
            throw AppFailure("Bağlantı motoru başlatılamadı. Bağlantı kontrolü ekranından ayrıntılara bakabilirsin.")
        }.value
        engineRunning = true
    }
    func startEngine(openDiscord: Bool = false) {
        guard !busy else { return };busy = true;error = nil
        Task { defer { busy = false };do { try await startEngineWork();notice = "Bağlantı motoru hazır.";if openDiscord { launchDiscord() } } catch { self.error = error.localizedDescription };refresh() }
    }
    func stopEngine() {
        guard !gateway.running else { showStopEngine = true;return }
        guard !busy else { return };busy = true
        Task { defer { busy = false };_ = try? await Task.detached { try Command.run("/bin/launchctl",["bootout","gui/\(getuid())/\(Product.agentID)"]) }.value;engineRunning = false;notice = "Bağlantı motoru kapatıldı.";refresh() }
    }
    func stopConnections() {
        guard !busy else { return }
        error = nil; notice = nil
        beginGatewayAction()
        if helperApproved {
            guard let p = proxy() else { endGatewayAction();return }
            p.stop { [weak self] data in Task { @MainActor in
                guard let self else { return }
                guard let state = try? JSONDecoder().decode(GatewayStatus.self,from:data), !state.running else {
                    self.error = "PS5 paylaşımı durdurulamadı. Bağlantı motoru açık bırakıldı.";self.endGatewayAction();return
                }
                self.gateway = state
                self.finishStoppingConnections()
            } }
        } else if gateway.running {
            error = "PS5 paylaşımı durdurulmadan motor kapatılamaz.";endGatewayAction()
        } else { finishStoppingConnections() }
    }
    private func finishStoppingConnections() {
        Task { [self] in
            defer { endGatewayAction();refresh() }
            do {
                try await Task.detached {
                    let job = "gui/\(getuid())/\(Product.agentID)"
                    if try Command.run("/bin/launchctl",["print",job]).status == 0 {
                        _ = try Command.checked("/bin/launchctl",["bootout",job])
                    }
                    for _ in 0..<40 {
                        if !SocketIO.available(Product.socksPort) && !SocketIO.available(Product.httpPort) { return }
                        try await Task.sleep(for:.milliseconds(100))
                    }
                    throw AppFailure("Bağlantı işlemleri henüz kapanmadı. Durumu yenileyip tekrar deneyin.")
                }.value
                engineRunning = false
                notice = "Bağlantı kapalı. PS5 kullanıyorsanız normal LAN profilini seçin."
            } catch { self.error = error.localizedDescription }
        }
    }
    // Inspect only Discord's launch configuration, never its messages or account data.
    // A new PID after a native update is checked again. Connected sessions are untouched.
    private func maintainDiscordConnection() {
        guard maintainDiscord, engineRunning, !busy, !discordInspectionPending else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier:"com.hnc.Discord")
        discordInspected.formIntersection(Set(running.map(\.processIdentifier)))
        guard let app = running.first, !discordInspected.contains(app.processIdentifier),
              let launched = app.launchDate, Date().timeIntervalSince(launched) >= 5 else { return }
        let pid = app.processIdentifier
        discordInspectionPending = true
        Task { [weak self] in
            let configured = await Task.detached { DiscordLaunchConfiguration.isConfigured(pid:pid) }.value
            guard let self else { return }
            self.discordInspectionPending = false
            guard self.maintainDiscord, self.engineRunning, !self.busy, !app.isTerminated else { return }
            guard let configured else { return } // Unreadable state is not permission to restart.
            self.discordInspected.insert(pid)
            guard !configured else { return }
            self.discordRepairs.removeAll { Date().timeIntervalSince($0) > 120 }
            guard self.discordRepairs.count < 3 else {
                self.error = "Discord art arda yeniden açıldı. Otomatik deneme durduruldu; Yeniden bağlan düğmesini kullanabilirsiniz."
                return
            }
            self.discordRepairs.append(Date())
            self.reconnectDiscord()
        }
    }
    func reconnectDiscord() {
        guard !busy else { return };busy = true;error = nil;notice = nil
        Task { [self] in
            defer { busy = false;refresh() }
            do {
                let running = NSRunningApplication.runningApplications(withBundleIdentifier:"com.hnc.Discord")
                for app in running { guard app.terminate() else { throw AppFailure("Discord kapatılamadı. Discord’dan çıkıp tekrar deneyin.") } }
                for _ in 0..<80 {
                    if running.allSatisfy({ $0.isTerminated }) { break }
                    try await Task.sleep(for:.milliseconds(100))
                }
                guard running.allSatisfy({ $0.isTerminated }) else { throw AppFailure("Discord kapanmayı bekliyor. Zorla kapatılmadı; uygulamadan çıkıp tekrar deneyin.") }
                try await startEngineWork()
                launchDiscord()
            } catch { self.error = error.localizedDescription }
        }
    }
    func launchDiscord() {
        let paths = [URL(fileURLWithPath:"/Applications/Discord.app"),FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Discord.app")]
        guard let app = paths.first(where:{ FileManager.default.fileExists(atPath:$0.path) }) else { error = "Discord kurulu görünmüyor. Önce discord.com üzerinden Discord’u yükle.";return }
        if NSRunningApplication.runningApplications(withBundleIdentifier:"com.hnc.Discord").count > 0 { notice = "Discord zaten açık. Bağlanmıyorsa Yeniden bağlan düğmesini kullanın.";NSRunningApplication.runningApplications(withBundleIdentifier:"com.hnc.Discord").first?.activate();return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.arguments = ["--proxy-server=socks5://127.0.0.1:\(Product.socksPort)"]
        var env = ProcessInfo.processInfo.environment;let proxy = "http://127.0.0.1:\(Product.httpPort)"
        for key in ["HTTPS_PROXY","HTTP_PROXY","ALL_PROXY","https_proxy","http_proxy"] { env[key] = proxy }
        configuration.environment = env
        NSWorkspace.shared.openApplication(at:app,configuration:configuration) { [weak self] _,err in if let err { Task { @MainActor in self?.error = err.localizedDescription } } }
    }
    func approveHelper() {
        do { try helper.register();refresh();if helper.status == .requiresApproval { notice = "Sistem Ayarları → Genel → Giriş Öğeleri ve Uzantılar bölümünden Luma’ya izin ver.";SMAppService.openSystemSettingsLoginItems() } }
        catch {
            refresh()
            if helper.status == .requiresApproval {
                self.error = nil
                notice = "Yardımcı kaydedildi. Sistem Ayarları’nda Luma’nın arka plan iznini bir kez onayla."
                SMAppService.openSystemSettingsLoginItems()
            } else { self.error = "macOS paylaşım yardımcısını kaydedemedi. Uygulamanın Uygulamalar klasöründe olduğunu ve imzasının geçerli olduğunu kontrol et. \(error.localizedDescription)" }
        }
    }
    func removeHelper() {
        guard !gateway.running, !busy else { return }
        do { try helper.unregister();connection?.invalidate();connection = nil;notice = "Paylaşım yardımcısının kaydı kaldırıldı.";refresh() }
        catch { self.error = "Yardımcı kaydı kaldırılamadı: \(error.localizedDescription)" }
    }
    private func beginGatewayAction() {
        let id = UUID(); pendingGatewayAction = id; busy = true
        Task { [weak self] in
            try? await Task.sleep(for:.seconds(15))
            guard let self, self.pendingGatewayAction == id else { return }
            self.endGatewayAction()
            self.connection?.invalidate(); self.connection = nil
            self.error = "macOS paylaşım yardımcısı zamanında yanıt vermedi. Kaydı Ayarlar’dan kaldırıp yeniden kurabilir veya tekrar deneyebilirsin."
        }
    }
    private func endGatewayAction() { pendingGatewayAction = nil; busy = false }
    func startGateway() {
        guard let n = network else { error = "Önce bir ağa bağlan.";return }
        do { try n.validateClient(clientIP) } catch { self.error = error.localizedDescription;return }
        guard helperApproved else { page = .console;notice = "PS5 paylaşımı için macOS iznini bir kez tamamla.";return }
        beginGatewayAction();let client = clientIP
        Task { [self] in
            do {
                try await startEngineWork()
                let request = try JSONEncoder().encode(GatewayRequest(client:client,expectedNetwork:n))
                guard let p = proxy() else { endGatewayAction();return }
                p.start(request) { [weak self] data in Task { @MainActor in self?.acceptStatus(data);self?.endGatewayAction();if self?.gateway.running == false { self?.error = self?.gateway.message } } }
            } catch { self.error = error.localizedDescription;endGatewayAction() }
        }
    }
    func stopGateway() {
        beginGatewayAction()
        guard let p = proxy() else { endGatewayAction();return }
        p.stop { [weak self] data in Task { @MainActor in self?.acceptStatus(data);self?.endGatewayAction();if self?.gateway.running == true { self?.error = self?.gateway.message } else { self?.notice = "Paylaşım kapandı. PS5’te normal LAN profilini seçebilirsin." } } }
    }
    func checkConnection() {
        guard !testing else { return };testing = true;page = .diagnostics
        checks = [HealthCheck(title:"Yerel ağ",detail:"Mac’in bağlantısı okunuyor",state:.checking),HealthCheck(title:"Bağlantı motoru",detail:"Henüz kontrol edilmedi",state:.waiting),HealthCheck(title:"Discord erişimi",detail:"Henüz kontrol edilmedi",state:.waiting),HealthCheck(title:"Güncelleme sunucusu",detail:"Henüz kontrol edilmedi",state:.waiting),HealthCheck(title:"Güncelleyici TLS 1.2 uyumluluğu",detail:"Henüz kontrol edilmedi",state:.waiting)]
        Task { [self] in
            for i in checks.indices {
                checks[i].state = .checking
                let result: (Bool,String) = await Task.detached {
                    switch i {
                    case 0: if let n = try? NetworkSnapshot.detect() { return (true,"\(n.interface) · \(n.address)") };return (false,"Etkin IPv4 bağlantısı bulunamadı")
                    case 1: return SocketIO.socksHealthy(Product.socksPort) && SocketIO.available(Product.httpPort) ? (true,"SOCKS ve güncelleme bağlantısı hazır") : (false,"Bağlantı motorunu başlatıp yeniden dene")
                    default:
                        let url = i == 2 ? "https://discord.com/api/v10/gateway" : "https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=osx&arch=\(Product.architecture)"
                        let tlsArguments = i == 4 ? ["--tls-max","1.2"] : [String]()
                        guard let r = try? Command.run("/usr/bin/curl",tlsArguments + ["--proxy","http://127.0.0.1:\(Product.httpPort)","--connect-timeout","4","--max-time","10","-sS","-o","/dev/null","-w","%{http_code}",url],timeout:12), r.status == 0 else { return (false,i == 4 ? "TLS 1.2 bağlantısı başarısız. Ayarlar’da Uyumlu TLS yöntemini deneyin." : "Bağlantı kurulamadı veya zaman aşımına uğradı") }
                        return r.text == "200" ? (true,"Sunucu yanıt verdi · HTTP 200") : (false,"Beklenmeyen sunucu yanıtı")
                    }
                }.value
                checks[i].state = result.0 ? .good : .failed;checks[i].detail = result.1
            }
            testing = false;lastChecked = Date()
        }
    }
    func exportDiagnostics() {
        let panel = NSSavePanel();panel.nameFieldStringValue = "Luma-tanilama.txt";panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK,let url = panel.url else { return }
        let summary = """
        Luma \(Product.version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Tarih: \(ISO8601DateFormatter().string(from:Date()))
        Motor: \(engineRunning ? "açık" : "kapalı")
        Paylaşım: \(gateway.running ? "açık" : "kapalı")
        Yöntem: \(preset.rawValue)
        Kontroller: \(checks.map { "\($0.title): \($0.state == .good ? "başarılı" : "tamamlanmadı")" }.joined(separator:"; "))
        IP, MAC adresleri, kullanıcı adı, mesajlar, oturum bilgileri ve ham ağ kayıtları dışa aktarılmadı.
        """
        do { try summary.write(to:url,atomically:true,encoding:.utf8);notice = "Kişisel ağ adresleri içermeyen tanılama kaydı kaydedildi." } catch { self.error = error.localizedDescription }
    }
    func setAutoStart(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() };autoStart = enabled } catch { self.error = error.localizedDescription }
    }
    func copySetup() {
        guard let n = network else { return }
        let text = "PS5 IP: \(clientIP)\nAlt ağ maskesi: \(n.mask)\nAğ geçidi: \(n.address)\nDNS: 1.1.1.1 / 1.0.0.1\nMTU: Otomatik\nProxy: Kullanma"
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(text,forType:.string);notice = "PS5 ayarları panoya kopyalandı."
    }
    func requestQuit() {
        if gateway.running || engineRunning {
            let a = NSAlert();a.messageText = "Luma kapatılsın mı?";a.informativeText = "Bağlantı motoru ve varsa PS5 paylaşımı durur. PS5’te normal LAN profilini seçerek doğrudan router’a dönebilirsin.";a.addButton(withTitle:"Durdur ve çık");a.addButton(withTitle:"Vazgeç")
            guard a.runModal() == .alertFirstButtonReturn else { return }
        }
        // Quit even if the helper never answers; it rolls back on its own once heartbeats stop.
        var finished = false
        func finish() {
            guard !finished else { return };finished = true
            _ = try? Command.run("/bin/launchctl",["bootout","gui/\(getuid())/\(Product.agentID)"]);NSApplication.shared.terminate(nil)
        }
        guard gateway.running, let p = proxy(reportErrors:false,onError:{ finish() }) else { finish();return }
        busy = true
        p.stop { _ in Task { @MainActor in finish() } }
        DispatchQueue.main.asyncAfter(deadline:.now()+6) { finish() }
    }
}
