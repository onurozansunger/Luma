import Foundation
import Darwin

/// Spawns inside the supervisor's process group so launchd can reap the child
/// after a supervisor crash. Call from one serial queue only.
public final class ManagedChild {
    public private(set) var processIdentifier: pid_t = 0
    private var reaped = false
    public init(executable: String, arguments: [String]) throws {
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw AppFailure("Alt süreç hazırlanamadı.") }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { throw AppFailure("Alt süreç ayarları hazırlanamadı.") }
        defer { posix_spawnattr_destroy(&attributes) }
        var empty = sigset_t(); sigemptyset(&empty)
        var defaults = sigset_t(); sigemptyset(&defaults)
        for value in [SIGTERM,SIGINT,SIGPIPE] { sigaddset(&defaults,value) }
        guard posix_spawnattr_setsigmask(&attributes,&empty) == 0,
              posix_spawnattr_setsigdefault(&attributes,&defaults) == 0,
              posix_spawnattr_setflags(&attributes,Int16(POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0 else { throw AppFailure("Alt süreç sinyalleri ayarlanamadı.") }
        for fd:Int32 in [0,1,2] {
            guard posix_spawn_file_actions_addopen(&actions,fd,"/dev/null",fd == 0 ? O_RDONLY : O_WRONLY,0) == 0 else { throw AppFailure("Alt süreç çıkışı ayarlanamadı.") }
        }
        var argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let environment: [String] = ["PATH=/usr/bin:/bin:/usr/sbin:/sbin","LC_ALL=C"]
        var env = environment.map { strdup($0) } + [nil]
        defer { for p in argv { free(p) }; for p in env { free(p) } }
        let result = argv.withUnsafeMutableBufferPointer { av in env.withUnsafeMutableBufferPointer { ev in
            posix_spawn(&processIdentifier,executable,&actions,&attributes,av.baseAddress!,ev.baseAddress!)
        } }
        guard result == 0 else { throw AppFailure("Alt süreç başlatılamadı (\(result)).") }
    }
    public var isRunning: Bool {
        guard !reaped, processIdentifier > 0 else { return false }
        var status:Int32 = 0
        let result = waitpid(processIdentifier,&status,WNOHANG)
        if result == processIdentifier || (result == -1 && errno == ECHILD) { reaped = true; return false }
        return true
    }
    public func terminate() { if isRunning { kill(processIdentifier,SIGTERM) } }
    public func stop(grace: TimeInterval = 2) {
        terminate()
        let deadline = Date().addingTimeInterval(grace)
        while isRunning && Date() < deadline { Thread.sleep(forTimeInterval:0.02) }
        if isRunning {
            kill(processIdentifier,SIGKILL)
            var status:Int32 = 0
            while waitpid(processIdentifier,&status,0) == -1 && errno == EINTR {}
            reaped = true
        }
    }
}
