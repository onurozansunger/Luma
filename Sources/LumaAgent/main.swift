import Foundation
import Darwin
import LumaCore

let args = CommandLine.arguments
func argument(_ key: String) -> String? { guard let i = args.firstIndex(of: key), i+1 < args.count else { return nil }; return args[i+1] }
let preset = ConnectionPreset(rawValue: argument("--preset") ?? "balanced") ?? .balanced
let own = Executable.currentURL()
let engine = own.deletingLastPathComponent().appendingPathComponent("ciadpi")
// Dispatch signal sources ignore signals in the supervisor. Reset them before exec
// so launchd can also terminate the engine process group if the supervisor crashes.
if args.dropFirst().first == "--engine-child" {
    signal(SIGTERM,SIG_DFL); signal(SIGINT,SIG_DFL)
    var emptyMask = sigset_t(); sigemptyset(&emptyMask); sigprocmask(SIG_SETMASK,&emptyMask,nil)
    // Foundation Process creates a new process group; join the launchd job's group
    // before exec so launchd can reap descendants after a supervisor crash.
    guard setpgid(0,getpgid(getppid())) == 0 else { exit(126) }
    let childArguments = [engine.path] + Array(args.dropFirst(2))
    let pointers = childArguments.map { strdup($0) } + [nil]
    pointers.withUnsafeBufferPointer { buffer in _ = execv(engine.path,buffer.baseAddress!) }
    exit(127)
}
let statusURL = Product.support.appendingPathComponent("agent-status.json")
try FileManager.default.createDirectory(at: Product.logs,withIntermediateDirectories: true,attributes:[.posixPermissions:0o700])
func status(_ state: String, _ restarts: Int) {
    let object: [String:Any] = ["state":state,"pid":getpid(),"restarts":restarts,"preset":preset.rawValue,"updatedAt":ISO8601DateFormatter().string(from:Date())]
    if let data = try? JSONSerialization.data(withJSONObject:object,options:.sortedKeys) { try? data.write(to:statusURL,options:.atomic) }
}
if SocketIO.available(Product.socksPort) || SocketIO.available(Product.httpPort) { status("port-conflict",0); exit(1) }
guard FileManager.default.isExecutableFile(atPath:engine.path) else { status("missing-engine",0); exit(1) }
let bridge = HTTPBridge(socksPort:Product.socksPort)
try bridge.listen(port:Product.httpPort)
var process: Process?; var restarts = 0; var stopping = false
let queue = DispatchQueue(label:"app.luma.agent.supervisor")
signal(SIGTERM,SIG_IGN); signal(SIGINT,SIG_IGN)
let sigterm = DispatchSource.makeSignalSource(signal:SIGTERM,queue:queue)
let sigint = DispatchSource.makeSignalSource(signal:SIGINT,queue:queue)
func stop() {
    stopping = true; bridge.stop()
    if let p = process, p.isRunning { p.terminate(); let end = Date().addingTimeInterval(2); while p.isRunning && Date() < end { Thread.sleep(forTimeInterval:0.05) }; if p.isRunning { kill(p.processIdentifier,SIGKILL) } }
    status("stopped",restarts); exit(0)
}
sigterm.setEventHandler(handler:stop); sigint.setEventHandler(handler:stop); sigterm.resume(); sigint.resume()
func start() {
    guard !stopping else { return }
    let p = Process(); p.executableURL = own; p.arguments = ["--engine-child","-i","127.0.0.1","-p",String(Product.socksPort),"--max-conn","512"] + preset.arguments
    p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
    let launched = Date()
    // Reset the backoff after a stable run so one old crash does not delay every later restart by 10 s.
    p.terminationHandler = { _ in queue.async { guard !stopping else { return }; if Date().timeIntervalSince(launched) > 60 { restarts = 0 }; restarts += 1; status("recovering",restarts); queue.asyncAfter(deadline:.now()+min(Double(restarts),10)) { start() } } }
    do { try p.run(); process = p; status("running",restarts) } catch { status("engine-error",restarts); exit(1) }
}
queue.async { start() }
dispatchMain()
