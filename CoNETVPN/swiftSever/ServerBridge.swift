//
//  ProxyBridge.swift
//  CoNETVPN
//
//  Created by peter on 2024-12-03.
//

import Network
import Foundation

class ServerBridge {
    var sendData: Data
    var tcpClient: NWConnection
    var proxyConnect: ServerConnection
    //The TCP maximum package size is 64K 65536
    let MTU = 65536
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            firstSend()
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    init(sendData: Data, host: NWEndpoint.Host, port: NWEndpoint.Port, proxyConnect: ServerConnection) {
        self.proxyConnect = proxyConnect
        self.sendData = sendData
        self.tcpClient = NWConnection(host: host, port: port, using: .tcp)
    }
    
    func start() {
        self.tcpClient.stateUpdateHandler = stateDidChange(to:)
        self.tcpClient.start(queue: .main)
    }
    
    private func tcpClientStartReceive() {
        self.tcpClient.receive(minimumIncompleteLength: 1, maximumLength: MTU) {(data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                self.proxyConnect.connection.send(content: data, completion: .contentProcessed ({ error in
                    if let error = error {
                        print("ServerBridge Node \(data.count) ---> APP Error!")
                        self.proxyConnect.connectionDidFail(error: error)
                        return self.stop(error: error)
                    }
                    print("ServerBridge send Node \(data.count) --->  APP SUCCESS!")
                }))
            }
            
            if let error = error {
                self.stop(error: error)
                return print("ServerBridge receive Node data ERROR \(error)!")
            }
            
            
            print("ServerBridge receive Node data \(data?.count ?? 0) isComplete ")
            self.tcpClientStartReceive ()
            
        }
        
    }
    
    private func proxyConnectStartReceive () {
        self.proxyConnect.connection.receive(minimumIncompleteLength: 1, maximumLength: self.MTU) {(data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let re = String(data: data, encoding: .utf8)
                self.tcpClient.send(content: data, completion: .contentProcessed ({ error in
                    if let error = error {
                        print("ServerBridge send APP \(data.count) --> Node Error!")
                        return self.connectionDidFail(error: error)
                    }
                    print("ServerBridge send APP \(data.count) --> Node success!")
                }))
            }
            
            if let error = error {
                self.proxyConnect.stop(error: error)
                return print("ServerBridge receive APP data ERROR \(error)!")
            }
            
            print("ServerBridge receive APP data \(data?.count ?? 0) isComplete ")
            self.proxyConnectStartReceive ()
        }
    }
    
    func firstSend() {
        
        proxyConnectStartReceive()
        tcpClientStartReceive()
        
        self.tcpClient.send(content: self.sendData, completion: .contentProcessed ({ error in
            if let error = error {
                print("ServerBridge --> Node Access ERROR!")
                return self.stop(error: error)
            }
            
            print("ServerBridge firstSend --> Node Access SUCCESS!")
            
        }))
    }
    
    private func connectionDidComplete(error: Error?) {
        print("ServerBridge connection did complete, error: \(String(describing: error))")
        stop(error: error)
    }
    
    private func connectionDidFail(error: Error) {
        print("ServerBridge connection did fail, error: \(error)")
        stop(error: error)
    }
    
    private func stop(error: Error?) {
        tcpClient.stateUpdateHandler = nil
        tcpClient.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
}
