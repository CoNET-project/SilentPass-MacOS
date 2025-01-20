import Foundation

struct Node: Codable {
    var country: String
    var ip_addr: String
    var region: String
    var armoredPublicKey: String
    var nftNumber: String
}

class NodeManager {
    static var allNodes: [Node] = []
    
    // 用于保存节点数组到 UserDefaults
    static func saveNodes() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(allNodes) // 将 Node 数组编码为 JSON 数据
            UserDefaults.standard.set(data, forKey: "allNodes") // 存储到 UserDefaults
            UserDefaults.standard.synchronize() // 
            print("Nodes successfully saved!")
        } catch {
            print("Failed to save nodes: \(error.localizedDescription)")
        }
    }
    
    // 用于从 UserDefaults 中读取节点数组
    static func loadNodes() {
        let decoder = JSONDecoder()
        guard let data = UserDefaults.standard.data(forKey: "allNodes") else {
            print("No nodes data found in UserDefaults")
            return
        }
        
        do {
            allNodes = try decoder.decode([Node].self, from: data) // 将 JSON 数据解码为 Node 数组
            print("Nodes successfully loaded!")
        } catch {
            print("Failed to load nodes: \(error.localizedDescription)")
        }
    }
}

// 示例用法
//NodeManager.allNodes = [
//    Node(country: "USA", ip_addr: "192.168.1.1", region: "California", armoredPublicKey: "ABCD1234", nftNumber: "NFT001"),
//    Node(country: "Canada", ip_addr: "192.168.1.2", region: "Toronto", armoredPublicKey: "EFGH5678", nftNumber: "NFT002")
//]
//
//// 保存到 UserDefaults
//NodeManager.saveNodes()
//
//// 清空数组，模拟重启应用
//NodeManager.allNodes = []
//
//// 从 UserDefaults 加载数据
//NodeManager.loadNodes()
//
//// 打印加载后的数据
//print(NodeManager.allNodes)
