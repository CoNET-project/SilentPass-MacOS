//
//  mining.swift
//  CoNETVPN
//
//  Created by peter on 2024-12-04.
//
import Network
import Foundation

class MiningProcess {
    let MTU = 65536
    var _layerMinus: LayerMinus
    var miningNode: NWConnection!
    var host = ""
    var privateKey = ""
    var firstSend: Data = "".data(using: .utf8)!
    var body = Data()
    var first = true
    init (layerMinus: LayerMinus) {
        self._layerMinus = layerMinus
    }
    
    
    func start() {
        self.first = true
        Task {
//            let miningNoed = LayerMinus.getRandomNodeFromEntryNodes()
            let miningNoed = LayerMinus.allNodes[0]
            if (miningNoed.ip_addr == "") {
                return print("MiningProcess Error! No mining node can found from getRandomNodeFromEntryNodes")
            }
            
            self.host = miningNoed.ip_addr
            let host = NWEndpoint.Host(self.host)
            let post = NWEndpoint.Port(80)
            self.miningNode = NWConnection(host: host, port: post, using: .tcp)
            self.miningNode.stateUpdateHandler = self.stateDidChange(to:)
            let _data =  try await self._layerMinus.createConnectCmd(node: miningNoed)
            
            let sendDate = self._layerMinus.makeRequest(host: self.host, data: _data)
            print(sendDate)
            self.firstSend = sendDate.data(using: .utf8)!
            self.miningNode.start(queue: .main)
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
    
    
    private func ready () {
        print("connectMining ready")
        self.miningNode.send(content: self.firstSend, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            print("connectMining did first")
            self.nextStep()
        }))
    }
    
    
    
    
    private func nextStep () {
        self.miningNode.receive(minimumIncompleteLength: 1, maximumLength: MTU) {(data, _, _, error) in
            if (error != nil) {
                return self.stop(error: error)
            }
            
            if let data = data, !data.isEmpty {
                self.body += data
                if let responseJSON = try? JSONSerialization.jsonObject(with: self.body, options: []) as? [String: Any] {
                    if let epoch = responseJSON["epoch"] as? String {
                        let nodeHash = responseJSON["hash"] as! String
                        Task {
                            let minerResponseHash = await self._layerMinus.signEphch(hash: nodeHash)
//                            print("Mining epoch \(epoch) \(self._layerMinus.privateKeyAromed)\nhash \(minerResponseHash)")
                            let nodeWallet = responseJSON["nodeWallet"] as! String
                            let nodeDomain = responseJSON["nodeDomain"] as! String
                            
                            if let callFun1 = self._layerMinus.javascriptContext.objectForKeyedSubscript("json_mining_response") {
                                if let ret1 = callFun1.call(withArguments: [epoch, self._layerMinus.walletAddress, nodeWallet, nodeHash, nodeDomain, minerResponseHash]) {
                                    let message = ret1.toString()!
                                    let messageData = message.data(using: .utf8)!
                                    let account = self._layerMinus.keystoreManager.addresses![0]
                                    let signMessage = try await self._layerMinus.web3.personal.signPersonalMessage(message: messageData, from: account, password: "")
                                    if let callFun2 = self._layerMinus.javascriptContext.objectForKeyedSubscript("json_sign_message") {
                                        if let ret2 = callFun2.call(withArguments: [message, "0x\(signMessage.toHexString())"]) {
                                            let cmd = ret2.toString()!
                                            print("Mining epoch \(epoch) \(self._layerMinus.privateKeyAromed)\nhash \(minerResponseHash)\n\(message)")

                                            LayerMinus.egressNodes.forEach { _node in
                                                let response = self._layerMinus.createValidatorData(node: _node, responseData: cmd)
                                                if !response.isEmpty {
                                                    let validNode = ValidatorPost(postData: response, node: _node.ip_addr, layerMinus: self._layerMinus )
                                                    validNode.start()
                                                }
                                            }
                                        }
                                    }
                                    
                                }
                            }
                            
                        }
                        self.body = "".data(using: .utf8)!
                    }
                } else {
                    if (self.first) {
                        self.body = "".data(using: .utf8)!
                        self.first = false
                    }
                }
                
                
                
            } else {
                print("nextStep data.isEmpty")
            }
            self.nextStep()
        }
        
    }
    
    func stop (error: Error?) {
        miningNode.stateUpdateHandler = nil
        miningNode.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
            self.start()
        }
    }
    var didStopCallback: ((Error?) -> Void)? = nil
    private func connectionDidComplete(error: Error?) {
        print("ServerBridge connection did complete, error: \(String(describing: error))")
        stop(error: error)
    }
    
    private func connectionDidFail(error: Error) {
        
        let userInfo: [String: Any] = ["当前通知类型": "网络连接失败"]
        NotificationCenter.default.post(name: .didUpdateConnectionNodes, object: nil, userInfo:userInfo)
        
        print("ServerBridge connection did fail, error: \(error)")
        stop(error: error)
    }
    
}
