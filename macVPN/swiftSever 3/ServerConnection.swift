//
//  ServerConnection.swift
//  tq-proxy-ios
//
//  Created by peter on 2024-11-14.
//

import Foundation
import Network




class ServerConnection {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536
    
    private static var nextID: Int = 0
    let  connection: NWConnection
    let id: Int
    let layerMinus: LayerMinus
    
    init(nwConnection: NWConnection, _layerMinus: LayerMinus) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
        layerMinus = _layerMinus
    }

    var didStopCallback: ((Error?) -> Void)? = nil

    func start() {
        print("connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }


    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("connection \(id) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    let proxyServerFirstResponse = "HTTP/1.1 200 Connection Established\r\n\r\n"
    let proxyServerFirstResponse_Error = "HTTP/1.1 503 no server was available\r\n\r\n"

    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) {(data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let header = String(data: data, encoding: .utf8) ?? ""
                print(header)
                if header.hasPrefix("CONNECT ") {
                    self.connection.receive(minimumIncompleteLength: 1, maximumLength: self.MTU) {(data1, _, isComplete, error) in
                        if let data1 = data1, !data1.isEmpty {
                            let body = data1.base64EncodedString()
                            return self.makeProxyConnect(header: header, body: body)
                        }
                    }
                    return self.send(data: self.proxyServerFirstResponse)
                }
                if header.hasPrefix("GET ") {
                    let body = data.base64EncodedString()
                    return self.makeProxyConnect(header: header, body: body)
                }
                
                return self.stop(error: nil)
            }
            
            if isComplete {
                print("ServerConnection \(self.id) receive did isComplete")
            }
            
            if let error = error {
                print("connection \(self.id) error")
                self.connectionDidFail(error: error)
            }
        }
    }
    
    func makeProxyConnect(header: String, body: String) {
        let _egressNode = self.layerMinus.getRandomEgressNodes()
        let _entryNode = self.layerMinus.getRandomEntryNodes()

        if (_egressNode.ip_addr == "" || _entryNode.ip_addr == "") {
            return self.proxyServerError()
        }
        
        let egressNode = _egressNode.ip_addr
        let entryNode = _entryNode.ip_addr
        
        if let callFun1 = self.layerMinus.javascriptContext.objectForKeyedSubscript("makeRequest") {
            
            if let ret1 = callFun1.call(withArguments: [header,body,self.layerMinus.walletAddress]) {
                let message = ret1.toString()!
                print(message)
                let messageData = message.data(using: .utf8)!
                let account = self.layerMinus.keystoreManager.addresses![0]
                Task {
                    let signMessage = try await self.layerMinus.web3.personal.signPersonalMessage(message: messageData, from: account, password: "")
                    if let callFun2 = self.layerMinus.javascriptContext.objectForKeyedSubscript("json_sign_message") {
                        if let ret2 = callFun2.call(withArguments: [message, "0x\(signMessage.toHexString())"]) {
                            let cmd = ret2.toString()!
                            let pre_request = self.layerMinus.createValidatorData(node: _egressNode, responseData: cmd)
                            let request = self.layerMinus.makeRequest(host: entryNode, data: pre_request)
                            let port = NWEndpoint.Port(rawValue: 80)!
                            let host = NWEndpoint.Host(entryNode)
                            let conBri = ServerBridge(sendData: request.data(using: .utf8)!, host: host, port: port, proxyConnect: self)
//                            print("Proxy connect started entry node:[ \(entryNode):\(_entryNode.ip_addr) ] egress node:[ \(egressNode):\(_egressNode.ip_addr) ] request:[ \(request) ]")
                            return conBri.start()
                        }
                    }
                }
            }
        }
    }
    
    func proxyServerError() {
        let sendData = proxyServerFirstResponse_Error.data(using: .utf8)!
        self.connection.send(content: sendData, completion: .contentProcessed( { error in
            if let _ = error {
                return
            }
            let userInfo: [String: Any] = ["当前通知类型": "网络连接失败","重试": "需重试"]
            NotificationCenter.default.post(name: .didUpdateConnectionNodes, object: nil, userInfo:userInfo)
            print("Proxy hasn't EgressNodes yet Error!")
            self.stop()
        }))
    }


    func send(data: String) {
        let sendData = data.data(using: .utf8)!
        self.connection.send(content: sendData, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            print("connection \(self.id) did send, data: \(data)")
        }))
    }

    func stop() {
        print("connection \(id) will stop")
    }

    func connectionDidFail(error: Error) {
        print("connection \(id) did fail, error: \(error)")
        stop(error: error)
    }

    private func connectionDidEnd() {
        print("connection \(id) did end")
        stop(error: nil)
    }

    func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}
