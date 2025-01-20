import WebKit
import UIKit
class NativeBridge: NSObject, WKScriptMessageHandler {
    
    private weak var webView: WKWebView?
    private var callbacks: [String: (Any?) -> Void] = [:]
    
    init(webView: WKWebView) {
        super.init()
        self.webView = webView
        
       
    }
    /**
     
    調用Javascript橋
    functionName：String javaScript中的函数名字
     arguments: 需要帶給javaScript函數的數據
     
     uuid:钩子名字    为什么要作为参数 因为有些固定参数的需要穿
     completion: 調用方等待的回調函數
                    
    示例
     
     
     解释
     */
    func callJavaScriptFunction(functionName: String, arguments: String, uuid: String, completion: @escaping (Any?) -> Void) {
        let callID = uuid
        
        // 保存回调
        callbacks[callID] = completion
        
        //      創建聆聽 JavaScript結束後呼叫 UUID
//        let configuration = WKWebViewConfiguration()
//        configuration.userContentController.add(self.webView as! WKScriptMessageHandler, name: callID)
        webView?.configuration.userContentController.add(self, name: callID)
        
          //呼叫js
             
        
                let javascript = "\(functionName)('\(callID)|||| \(arguments)')"

        
                webView?.evaluateJavaScript(javascript) { (result, error) in
                    if let error = error {
                        print("Error evaluating JavaScript: \(error.localizedDescription)")
                    }
                }
            
        
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
     
        
        // 查找并执行对应的回调
        if let callback = callbacks[message.name] {
            callback(message.body)
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: message.name)
            
            print("ios收到的回调  回调名字: \(message.name), 回调内容: \(message.body)")
            
        }
    }
}


