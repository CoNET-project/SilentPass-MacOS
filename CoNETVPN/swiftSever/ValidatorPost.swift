//
//  VPost.swift
//  CoNETVPN
//
//  Created by peter on 2024-12-06.
//
import Network
import Foundation

class ValidatorPost {
    let MTU = 65536
    var firstSend = ""
    var validatorEntryNode: NWConnection
    var host: String
    init (postData: String, node: String, layerMinus: LayerMinus) {
        
        self.firstSend = layerMinus.makeRequest(host: node, data: postData)
        self.host = node
        let port = NWEndpoint.Port(rawValue: 80)!
        let _host = NWEndpoint.Host(node)
        self.validatorEntryNode = NWConnection(host: _host, port: port, using: .tcp)
        
        
    }
    
    func start () {
        self.validatorEntryNode.stateUpdateHandler = self.stateDidChange(to:)
        self.validatorEntryNode.start(queue: .main)
    }
    
    private func ready () {
        
        let sendDate = self.firstSend.data(using: .utf8)!
        self.validatorEntryNode.send(content: sendDate, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            print("ValidatorPost send \(self.host) success!")
            self.nextStep()
        }))
    }
    
    private func nextStep() {
        self.validatorEntryNode.receive(minimumIncompleteLength: 1, maximumLength: MTU) {(data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                
            }
            if let error = error {
                print("ValidatorPost receive data ERROR! \(error)")
            }
            
            self.stop(error: nil)
        }
    }
    
    func stop (error: Error?) {
        validatorEntryNode.stateUpdateHandler = nil
        validatorEntryNode.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            ready()
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    var didStopCallback: ((Error?) -> Void)? = nil
    private func connectionDidComplete(error: Error?) {
        print("ServerBridge connection did complete, error: \(String(describing: error))")
        stop(error: error)
    }
    
    private func connectionDidFail(error: Error) {
        print("ServerBridge connection did fail, error: \(error)")
        stop(error: error)
    }
}
