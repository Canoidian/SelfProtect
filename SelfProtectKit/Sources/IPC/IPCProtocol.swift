import Foundation

@objc public protocol HelperProtocol {
    func startBlock(configData: Data, reply: @escaping (Data?) -> Void)
    func stopBlock(reply: @escaping (Bool, String?) -> Void)
    func getStatus(reply: @escaping (Data) -> Void)
    func updateConfig(configData: Data, reply: @escaping (Bool, String?) -> Void)
}

public let helperMachServiceName = "com.selfprotect.helper.xpc"
public let helperLabel = "com.selfprotect.helper"
