//
//  javaScriptBridge.swift
//  tq-proxy-ios
//
//  Created by peter on 2024-11-19.
//
import WebKit
import Foundation

class JavaScriptBridge {
    var webView: WKWebView!
    let configuration = WKWebViewConfiguration()
    init(webView: WKWebView) {
        self.webView = webView
    }
    
    private var completionHandlerByUUID: [String:(String?) -> Void] = [:]

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //      JavaScript 呼叫 UUID
        //      獲得UUID指向的回調函數
        let completionHandler = completionHandlerByUUID[message.name]
        //      如果存在則執行回調函數
        completionHandler?(message.body as? String)
        
        //      釋放UUID所指向的記憶的回調函數
        completionHandlerByUUID.removeValue(forKey: message.name)
        configuration.userContentController.removeScriptMessageHandler(forName: message.name)
        
    }
    /**
     
    調用Javascript橋
    cmd：String javaScript中的命令
    arg: 需要帶給javaScript函數的數據
    completionHandler: 調用方等待的回調函數
                    
                    
     */
    func call (cmd: String, arg: String, completionHandler: @escaping (String?) -> Void) {
        //      給調用生成一個UUID
        let uuid = UUID().uuidString
        //      製造通訊用串，帶入UUID
        let command = "cmd: \(cmd), arg: \(arg), uuid: \(uuid)"
        //      記憶uuid->回調函數
        completionHandlerByUUID[uuid] = completionHandler
        //      創建聆聽 JavaScript結束後呼叫 UUID
        
        configuration.userContentController.add(self.webView as! WKScriptMessageHandler, name: uuid)
        //      呼叫JavaScript入口
        let js = "FX168SendRegion('\(String(describing: command))')"
        
    }
}
