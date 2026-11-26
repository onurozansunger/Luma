// Compile as a separate executable, outside Luma.app, to test peer rejection.
// Requires the actual registered helper. It requests status only; never start/stop.
import Foundation
@objc protocol ProbeProtocol {
    func status(reply: @escaping (Data) -> Void)
}
let connection = NSXPCConnection(machServiceName:"app.luma.gateway",options:.privileged)
connection.remoteObjectInterface = NSXPCInterface(with:ProbeProtocol.self)
connection.resume()
let result = DispatchSemaphore(value:0)
var rejected = false
let proxy = connection.remoteObjectProxyWithErrorHandler { error in
    print("Peer rejected: \(error.localizedDescription)");rejected = true;result.signal()
} as! ProbeProtocol
proxy.status { _ in print("FAIL: unrelated executable received helper status");result.signal() }
if result.wait(timeout:.now()+8) == .timedOut { print("INCONCLUSIVE: timeout");exit(2) }
connection.invalidate()
exit(rejected ? 0 : 1)
