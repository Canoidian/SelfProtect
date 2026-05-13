import Foundation
import SelfProtectKit

class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        let helper = Helper()
        newConnection.exportedObject = helper
        newConnection.resume()
        return true
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
