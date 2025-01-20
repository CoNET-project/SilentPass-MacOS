//
//  LayerMinus.swift
//  CoNETVPN
//
//  Created by peter on 2024-12-09.
//


struct NodeRegion {
    var node: Node
    var time: Double
}

import Foundation
import Web3Core
import web3swift
import ObjectivePGP
import JavaScriptCore


class LayerMinus {
    static let maxRegionNodes = 5
    static let rpc = "http://207.90.195.48"
    static let rpcUrl = URL(string: LayerMinus.rpc)!
    let tempKeystore = try! EthereumKeystoreV3(password: "")
    let keystoreManager: KeystoreManager
    var walletAddress = ""
    var privateKeyAromed = ""
    let keyring = Keyring()
    let pgpKey = KeyGenerator().generate(for: "user@conet.network", passphrase: "")
    
    static var currentScanNode = 100
    static var country = Set<String>()
    static var entryNodes: [Node] = []
    static var egressNodes: [Node] = []
    static var allNodes: [Node] = []
    static var nearbyCountryTestNodes: [NodeRegion] = []
    static var nearbyCountry = ""
    let javascriptContext: JSContext = JSContext()
    var miningProcess: MiningProcess!
    var web3: Web3!
    var CONET_Guardian_NodeInfo_ABI: String!
    var CONET_Guardian_NodeInfo_Contract: EthereumContract!
    
    func initializeJS() {
        self.javascriptContext.exceptionHandler = { context, exception in
            if let exc = exception {
                print("JS Exception:", exc.toString() as Any)
            }
        }
        let jsSourceContents = "let _makeRequest=(header,body) => {var headers = header.split('\\r\\n')[0]; var commandLine = headers.split(' '); var hostUrl = commandLine[1]; var host = /http/.test(hostUrl)?hostUrl.split('http://')[1].split('/')[0]:hostUrl.split(':')[0]; var port = parseInt(hostUrl.split(':')[1])||80; return { host, buffer: body||header, cmd: body.length ? 'CONNECT' : 'GET', port, order: 0 };};\nvar json_string=(data)=>JSON.stringify({data});var json_command=(data)=>JSON.stringify({command: 'mining', algorithm: 'aes-256-cbc', Securitykey: '', walletAddress: data});var json_sign_message=(message,signMessage)=>JSON.stringify({message,signMessage});var json_mining_response=(eposh,walletAddress,nodeWallet,hash,nodeDomain,minerResponseHash )=>JSON.stringify({Securitykey:'',walletAddress,algorithm:'aes-256-cbc',command:'mining_validator',requestData:{epoch:parseInt(eposh),nodeWallet,hash,nodeDomain,minerResponseHash,isUser:true}});var makeRequest=(header,body,walletAddress)=>JSON.stringify({command:'SaaS_Sock5',algorithm:'aes-256-cbc',Securitykey:'',requestData:[_makeRequest(header,body)],walletAddress});var getResult=(res)=> JSON.parse(res)[1].result;"
        self.javascriptContext.evaluateScript(jsSourceContents)
    }
    
    
    func createValidatorData (node: Node, responseData: String) -> String {
        let nodePGP = node.armoredPublicKey
        let cmdData = responseData.data(using: .utf8)!.base64EncodedString().data(using: .utf8)!
        do {
            let keys = try ObjectivePGP.readKeys(from: nodePGP.data(using: .utf8)!)
            let encrypted = try ObjectivePGP.encrypt(cmdData, addSignature: false, using: keys)
            let armoredRet = Armor.armored(encrypted, as: .message)
            if let functionFullname = self.javascriptContext.objectForKeyedSubscript("json_string") {
                if let fullname = functionFullname.call(withArguments: [armoredRet]) {
                    return fullname.toString()
                }
            }
        } catch {
            
        }
        return ""
        
    }

    
    func createConnectCmd (node: Node) async throws -> String {
        
        if let callFun1 = self.javascriptContext.objectForKeyedSubscript("json_command") {
            if let ret1 = callFun1.call(withArguments: [self.walletAddress]) {
                let message = ret1.toString()!
                let messageData = message.data(using: .utf8)!
//                let nodePGP = node.armoredPublicKey
                let account = self.keystoreManager.addresses![0]
                let signMessage = try await self.web3.personal.signPersonalMessage(message: messageData, from: account, password: "")
//                print(self.privateKeyAromed, signMessage.toHexString(), message)
                
                if let callFun2 = self.javascriptContext.objectForKeyedSubscript("json_sign_message") {
                    if let ret2 = callFun2.call(withArguments: [message, "0x\(signMessage.toHexString())"]) {
                        let cmd = ret2.toString()!
                        return self.createValidatorData(node: node, responseData: cmd)
                    }
                }
            }
        }
        return ""
    }
    
    init () {
        
        self.keystoreManager = KeystoreManager([self.tempKeystore!])
        let account = self.keystoreManager.addresses![0]
        self.walletAddress = account.address.lowercased()
        self.initializeJS()
        self.miningProcess = MiningProcess(layerMinus: self)
        self.readCoNET_nodeInfoABI()
        do {
            let privateKey = try self.keystoreManager.UNSAFE_getPrivateKeyData(password: "", account: account)
            self.privateKeyAromed = privateKey.toHexString()
        } catch {
            print ("Error getting private key")
        }
        Task{
            self.web3 = try await Web3.new(LayerMinus.rpcUrl)
            web3.addKeystoreManager(self.keystoreManager)
            
        }
        
    }
    
    func makeRequest(host: String, data: String) -> String {
        var ret = "POST /post HTTP/1.1\r\n"
        ret += "Host: \(host)\r\n"
        ret += "Content-Length: \(data.count)\r\n\r\n"
        ret += data
        ret += "\r\n"
        
        return ret
    }
    
    static func getRandomEntryNodes () -> Node {
        if LayerMinus.entryNodes.isEmpty {
            return Node(country: "", ip_addr: "", region: "", armoredPublicKey: "", nftNumber: "")
        }
        let randomIndex = Int.random(in: 0..<LayerMinus.entryNodes.count)
        return LayerMinus.entryNodes[randomIndex]
    }
    
    static func getRandomEgressNodes() -> Node {
        if LayerMinus.egressNodes.isEmpty {
            return Node(country: "", ip_addr: "", region: "", armoredPublicKey: "", nftNumber: "")
        }
        let randomIndex = Int.random(in: 0..<LayerMinus.egressNodes.count)
        return LayerMinus.egressNodes[randomIndex]
    }
    
    func signEphch (hash: String) async -> String {
        let account = self.keystoreManager.addresses![0]
        do {
            let signMessage = try await self.web3.personal.signPersonalMessage(message: hash.data(using: .utf8)!, from: account, password: "")
            return "0x\(signMessage.toHexString())"
        } catch {
            return ""
        }
       
    }
    
    func readCoNET_nodeInfoABI () {
        if let jsSourcePath = Bundle.main.path(forResource: "CONET_Guardian_NodeInfo_ABI", ofType: "text") {
            do {
                self.CONET_Guardian_NodeInfo_ABI = try String(contentsOfFile: jsSourcePath)
                self.CONET_Guardian_NodeInfo_Contract = try EthereumContract(self.CONET_Guardian_NodeInfo_ABI, at: nil)
            } catch {
                print("readCoNET_nodeInfoABI Error")
            }
        }
    }
    
    
    func start () {

        let st = String(format:"%03X", LayerMinus.currentScanNode)
        print("\(LayerMinus.currentScanNode)")
        
        NodeManager.loadNodes()
        
        CountryManager.loadCountries()
        if NodeManager.allNodes.count > 0
        {
            LayerMinus.allNodes =  NodeManager.allNodes
            LayerMinus.country = CountryManager.country
            self.miningProcess.start()
            
            return self.testRegion()
        }
        
        
        getNode(nftNumber: st, completion: { result in
            
            if !result {
                print("getAllNodes Stop at \(LayerMinus.currentScanNode) regions \(LayerMinus.country.sorted())")
                NotificationCenter.default.post(name: .didUpdateConnectionNodes, object: nil, userInfo:nil)
                
                NodeManager.allNodes = LayerMinus.allNodes
                // 保存到 UserDefaults
                NodeManager.saveNodes()
                
                CountryManager.country = LayerMinus.country
                CountryManager.saveCountries()
                
                
                
                return self.testRegion()
            }
            if st == "06E" {
                self.miningProcess.start()
            }
            LayerMinus.currentScanNode += 1
            
            self.start()
            
        })
        
        
    }
    
    static func getRandomNodeWithRegion(country: String) -> Node {
        let allNodes = LayerMinus.allNodes.filter { $0.country == country }
        let randomIndex = Int.random(in: 0..<allNodes.count)
        return allNodes[randomIndex]
    }
    
    func testRegion() {
        
        var allNodes:[NodeRegion] = []
        LayerMinus.country.forEach { country in
            let node = LayerMinus.getRandomNodeWithRegion(country: country)
            self.testNodeDelay(node: node, completion: { time in
                allNodes.append(NodeRegion(node: node, time: time))
                if allNodes.count == LayerMinus.country.count {
                    let sortedNodes = allNodes.sorted { $0.time < $1.time }
                    LayerMinus.nearbyCountryTestNodes = sortedNodes
                    LayerMinus.nearbyCountry = sortedNodes[0].node.country
                    self.makeEntryNodes()
                    self.setupEgressNodes(country: "US")
                    print("testRegion finished !")
                    NotificationCenter.default.post(name: .didUpdateConnectionNodes, object: nil, userInfo:nil)
                    
//                    self.miningProcess = MiningProcess(layerMinus: self)
//                    self.miningProcess.start()
                }
            })
        }
        
    }
    
    func setupEgressNodes (country: String) {
        if !LayerMinus.country.contains(country) {
            return print("setupEgressNodes has't \(country) in country array ERROR!")
        }
        LayerMinus.egressNodes = []
        repeat {
            let node = LayerMinus.getRandomNodeWithRegion(country: country)
            LayerMinus.egressNodes.append(node)
            
        } while LayerMinus.egressNodes.count < LayerMinus.maxRegionNodes
        print("setupEgressNodes at \(country) success!")
        
        var entryNodes = NSMutableArray()
        var egressNodes = NSMutableArray()
        
        for node in LayerMinus.egressNodes {
            
            entryNodes.add(node.ip_addr)
        }
        for node in LayerMinus.entryNodes {
            
            egressNodes.add(node.ip_addr)
        }
        
        
        
        
        let userDefaults = UserDefaults(suiteName: "group.com.fx168.CoNETVPN1.CoNETVPN1")
        userDefaults?.set(entryNodes, forKey: "entryNodes")
        userDefaults?.set(egressNodes, forKey: "egressNodes")
        userDefaults?.synchronize()
        
        
        
        
        
        if let userDefaults = UserDefaults(suiteName: "group.com.fx168.CoNETVPN1.CoNETVPN1") {
            if let entryNodesArray = userDefaults.array(forKey: "entryNodes"),
               let egressNodesArray = userDefaults.array(forKey: "egressNodes") {
               
                // 合并数组并强制转换为 [String]
                let combinedArray = (entryNodesArray + egressNodesArray).compactMap { $0 as? String }
                
                
                let entryNodesArray1 = entryNodesArray.compactMap { $0 as? String }
                
                let egressNodesArray1 = egressNodesArray.compactMap { $0 as? String }
                
                
//                localServer?.putNodes(entryNodes: entryNodesArray1, egressNodes: egressNodesArray1, privateKey: privateKey)
                
                // 添加额外的条目到 exceptionList
                let updatedArray = combinedArray + [
                    "192.168.0.0/16",
                    "10.0.0.0/8",
                    "172.16.0.0/12",
                    "169.254.0.0/12",
                    "127.0.0.1",
                    "localhost",
                    "*.local"
                ]
                
                
                
                
                print(updatedArray) // 验证合并结果
                // 更新 proxySettings 的 exceptionList
            }
        }
        
        
    }
    
    func makeEntryNodes () {
        repeat {
            let node = LayerMinus.getRandomNodeWithRegion(country: LayerMinus.nearbyCountry)
            LayerMinus.entryNodes.append(node)
        } while LayerMinus.entryNodes.count < LayerMinus.maxRegionNodes
    }
    
    func testNodeDelay(node: Node, completion: @escaping (Double) -> Void) {
        let url = URL(string: "http://\(node.ip_addr)/")!
        let request = URLRequest(url: url)
        
        let before = Date()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data else { return }
            var _ = String(data: data, encoding: .utf8)!
            let after = Date()
            let timeInterval = after.timeIntervalSince(before)
            print("testNodeDelay \(node.ip_addr) = \(timeInterval)")
            completion(timeInterval)
        }
        
        task.resume()
    }
    
    func getNode(nftNumber: String, completion: @escaping (Bool) -> Void) {
        
        var request = URLRequest(url: LayerMinus.rpcUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let postString = "[{\"method\":\"eth_chainId\",\"params\":[],\"id\":1,\"jsonrpc\":\"2.0\"},{\"method\":\"eth_call\",\"params\":[{\"to\":\"0x9e213e8b155ef24b466efc09bcde706ed23c537a\",\"data\":\"0xc839a8f10000000000000000000000000000000000000000000000000000000000000\(nftNumber)\"},\"latest\"],\"id\":2,\"jsonrpc\":\"2.0\"}]"
        request.httpBody = postString.data(using: .utf8)
        
        DispatchQueue.main.async {
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("错误输出 \(String(describing: error)) ")
                    return completion(false)
                }
                let _res = String(data: data, encoding: .utf8)!
                
                if let callFun1 = self.javascriptContext.objectForKeyedSubscript("getResult") {
                    if let ret1 = callFun1.call(withArguments: [_res]) {
                        let res = ret1.isUndefined ? "" : ret1.toString()!
                        let _resData = Data(hex:res)
                        do {
                            let decodedData = try self.CONET_Guardian_NodeInfo_Contract.decodeReturnData("getNodeInfoById", data: _resData)
                            guard let ip_addr = decodedData["ipaddress"] as? String else {
                                return print("getNode ipaddress error")
                            }
                            guard let regionName = decodedData["regionName"] as? String else {
                                return print("getNode regionName error")
                            }
                            guard let pgp = decodedData["pgp"] as? String else {
                                return print("getNode pgp error")
                            }
                            if (pgp.isEmpty) {
                                return completion(false)
                            }
                            
                            let armoredPublicKey = String(data: Data(base64Encoded: pgp) ?? Data(), encoding: .utf8)!
                            let _country = regionName.split(separator: ".")[1]
                            let country = String(_country)
                            LayerMinus.country.insert(country)
                            let node = Node(country: country, ip_addr: ip_addr, region: regionName, armoredPublicKey: armoredPublicKey, nftNumber: nftNumber)
                            LayerMinus.allNodes.append(node)
                            completion(true)
                        } catch {
                            return completion(false)
                        }
                    }
                }
            }
            task.resume()
        }
    }
    
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

extension FixedWidthInteger {
    var data: Data {
        let data = withUnsafeBytes(of: self) { Data($0) }
        return data
    }
}
