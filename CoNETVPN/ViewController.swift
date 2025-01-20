//
//  ViewController.swift
//  CoNETVPN
//
//  Created by 杨旭的MacBook Pro on 2024/11/23.
//

import Cocoa
import os.log
import NetworkExtension
import SnapKit
import WebKit
class ViewController: NSViewController {
    var index = 1
    var timer: Timer?
    let log = Logger(subsystem: "com.fx168.maxVPN.CoNETVPN", category: "app")
    var indexstate = 0
    var indexChangeUS = "切换节点"
    var loadingHUD: LoadingHUD?
    var countryIndex:String = "US"
    var countriesArray:Array<String> = [];
    var localServer: Server?
    var layerMinus: LayerMinus!
    var nativeBridge: NativeBridge!
    
    let label = NSTextField(labelWithString: "当前状态：正在扫描全部节点，请稍等（如果是第一次加载速度会比较慢，请稍等哦）")
    // 创建一个可输入的 NSTextField
    let inputTextField = NSTextField(labelWithString: "当前节点区域美国")
    
    
    let vpnstateTextField = NSTextField(labelWithString: "当前vpn开启状态")
    
    let regionView = NSView()
    
    let statebutton = NSButton()
    let vpnbutton = NSButton()
    var vPNManager: VPNManager!
    
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.log.log(level: .debug, "app启动")
        NSLog("测试输出 - PacketTunnelProvider 启动")
        print("Print 测试 - PacketTunnelProvider 启动")
        // 设置标签的属性
               label.alignment = .center               // 文本居中
               label.font = NSFont.systemFont(ofSize: 24) // 字体大小
               label.textColor = NSColor.black        // 字体颜色
               // 设置标签的框架位置和大小
               label.frame = NSRect(x: 100, y: 170, width: 300, height: 30)
               // 将标签添加到视图中
               view.addSubview(label)
        
        label.snp.makeConstraints {(make) -> Void in
            
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(self.view).offset(16)
            make.height.equalTo(30)
            
        }
        
//        label.sizeToFit()
        
        // 设置文本框的初始值和其他属性
            
        inputTextField.alignment = .center               // 文本居中
        inputTextField.font = NSFont.systemFont(ofSize: 13) // 字体大小
        inputTextField.textColor = NSColor.black        // 字体颜色
        // 设置标签的框架位置和大小
        // 将标签添加到视图中
        view.addSubview(inputTextField)
        
        inputTextField.snp.makeConstraints {(make) -> Void in
            
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(label.snp.bottom).offset(20)
            make.height.equalTo(30)
            
        }
        
        
        self.view.addSubview(regionView)
        regionView.snp.makeConstraints { (make) -> Void in
            
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(inputTextField.snp.bottom).offset(8)
            make.height.equalTo(90)

        }
        
        
        // 创建按钮
        statebutton.title = "重新连接当前区域节点"
        // 设置目标和动作
//        statebutton.isHidden = true
        statebutton.target = self
        statebutton.action = #selector(reconnectcurrentNode)
        statebutton.frame = NSRect(x: 100, y: 80, width: 300, height: 30) // 设置按钮位置和大小
              // 将按钮添加到视图
              self.view.addSubview(statebutton)
        
        statebutton.snp.makeConstraints {(make) -> Void in
            
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(regionView.snp.bottom).offset(5)
            make.height.equalTo(30)

        }
        
        
        
        let closebutton = NSButton(title: "更新全部节点(速度较慢)", target: self, action: #selector(allupdatenode))
        closebutton.frame = NSRect(x: 100, y: 50, width: 300, height: 30) // 设置按钮位置和大小
        // 将按钮添加到视图
        self.view.addSubview(closebutton)
        
        closebutton.snp.makeConstraints { (make) -> Void in
            
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(statebutton.snp.bottom).offset(20)
            make.height.equalTo(30)

        }
        
        
        vpnstateTextField.alignment = .center               // 文本居中
        vpnstateTextField.font = NSFont.systemFont(ofSize: 13) // 字体大小
        vpnstateTextField.textColor = NSColor.black        // 字体颜色
        // 设置标签的框架位置和大小
        // 将标签添加到视图中
        view.addSubview(vpnstateTextField)
        
        vpnstateTextField.snp.makeConstraints {(make) -> Void in
            
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(closebutton.snp.bottom).offset(20)
            make.height.equalTo(30)
        }
        
        
     
        // 创建按钮
        vpnbutton.title = "启动VPN"
        vpnbutton.target = self
        vpnbutton.action = #selector(startVPN)
        vpnbutton.frame = NSRect(x: 100, y: 80, width: 300, height: 30)
        self.view.addSubview(vpnbutton)
        
        vpnbutton.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.view).offset(16)
            make.right.equalTo(self.view).offset(-16)
            make.top.equalTo(vpnstateTextField.snp.bottom).offset(0)
            make.height.equalTo(30)
        }
       
        
        
        //  初始化
        self.layerMinus = LayerMinus(port: 8888)
//        self.layerMinus.scanAll_nodes()
        self.localServer = Server(port: 8888, layerMinus: self.layerMinus )
        self.localServer?.start()
        self.vPNManager = VPNManager(layerMinus: self.layerMinus)
        
//        WebViewManager.shared.layerMinusInit();
        
      
        let jsbutton = NSButton(title: "启动VPN获取节点", target: self, action: #selector(testJS))
        jsbutton.isHidden = true
        jsbutton.frame = NSRect(x: 100, y: 10, width: 300, height: 30) // 设置按钮位置和大小
        // 将按钮添加到视图
        self.view.addSubview(jsbutton)
        print("启动初始化服务器放在app启动时候  不放在startServer 按钮了，要不然没有拿到区域信息  再次点击会崩溃")
        //         初始化服务器，设置端口为8888
//        var privateKey = "a1eface56495c717f382a602e9cca40b61eb0b9f2ebb7addbdd8aad18e3f3847"
//        var _privateKey = Data.fromHex(privateKey)!
       
//                let delay = DispatchTime.now() + 1
//                    DispatchQueue.main.asyncAfter(deadline: delay) {
                      
        
//        app运行起来2秒在做操作，不然容易加载失败
//                        self.layerMinus = LayerMinus()
//                        self.layerMinus.scanAll_nodes()
//
//                        self.localServer = Server(port: 8888, layerMinus: self.layerMinus )
//                                // 启动服务器
//                        self.localServer?.start()
//                        self.vPNManager = VPNManager(layerMinus: self.layerMinus)
        
        // 初始化 WebView
//               let webViewConfiguration = WKWebViewConfiguration()
//               webView = WKWebView(frame: view.bounds, configuration: webViewConfiguration)
//               webView.autoresizingMask = [.width, .height]
//               view.addSubview(webView)
        
//        let scaleFactor = 0.7
//        let width = 500 * scaleFactor
//        let height = 806 * scaleFactor
//        webView.snp.makeConstraints { (make) -> Void in
//            make.right.equalTo(self.view).offset(-16)
//            make.top.equalTo(self.view).offset(300)
//            make.height.equalTo(height)
//            make.width.equalTo(width)
//        }

               // 加载网页
//               if let url = URL(string: "https://vpn.conet.network/#/") {
//                   let request = URLRequest(url: url)
//                   webView.load(request)
//               }
        
        
        
//                    }
        
        
        
        // 1. 创建 WebView 配置
        
                let config = WKWebViewConfiguration()
                let userContentController = WKUserContentController()
        
                // 2. 添加与 JS 的交互 (通过 MessageHandler)
//                userContentController.add(self, name: "starAppVPN")
//                userContentController.add(self, name: "stopAppVPN")
//                config.userContentController = userContentController

                // 3. 初始化 WebView
                webView = WKWebView(frame: .zero, configuration: config)
                webView.navigationDelegate = self
       
                self.view.addSubview(webView)

                // 4. 使用 AutoLayout
                webView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    webView.topAnchor.constraint(equalTo: view.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
        //      初始化 JS 的交互
        self.nativeBridge = NativeBridge(webView: webView, viewController: self)
        
        // 5. 加载目标 URL
        if let url = URL(string: "https://vpn-beta.conet.network/#/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }

               
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNodeUpdate(notification:)), name: .didUpdateConnectionNodes, object: nil)
        
//        DispatchQueue.main.async{
//            self.loadingHUD = LoadingHUD(message: "加载中...第一次加载全部节点较慢，请稍等")
//            self.loadingHUD?.show(in: self.view.window!)
//            
//        }
        
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("VPNStatusChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let status = notification.object as? NEVPNStatus {
                // 更新 UI 或同步状态
//                print("我的VPN状态mac: \(status)")
                
                if status.rawValue == 3
                {
                    self.indexstate = 3
                    self.vpnbutton.title = "关闭VPN"
                    
                    self.vpnstateTextField.stringValue = "当前VPN状态:已连接"
                    
                }
                else if status.rawValue == 0
                {
                    self.vpnstateTextField.stringValue = "当前VPN状态:未创建"
                }
                else if status.rawValue == 2
                {
                    self.vpnstateTextField.stringValue = "当前VPN状态:正在连接"
                }
                else if status.rawValue == 4
                {
                    self.vpnstateTextField.stringValue = "当前VPN状态:正在重新连接"
                }
                else if status.rawValue == 5
                {
                    self.vpnstateTextField.stringValue = "当前VPN状态:正在断开"
                }
                else
                {
                    self.indexstate = 1
                    self.vpnbutton.title = "启动VPN"
                    self.vpnstateTextField.stringValue = "当前VPN状态:已断开,请重新点击下方开启vpn按钮重试"
                }
                let state = String(status.rawValue)
                
                let jsFunction = "appVpnState('\(state)');"
                if (self.webView != nil)
                {
                    
                    self.nativeBridge.callJavaScriptFunction(functionName: "appVpnState", arguments: state) { result in
                        if let result = result as? Int {
                                print("JavaScript result: \(result)") // 输出 8
                            } else {
                                print("Failed to get a valid result")
                            }
                    }
//                    self.webView.evaluateJavaScript(jsFunction) { (result, error) in
//                        if let error = error {
//                            print("Error executing JS: \(error)")
//                        } else {
//                            print("JS Result: \(result ?? "No result")")
//                        }
//                    }
                }
                
                
                
            }
        }
        
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(getVPNConfigurationStatus), userInfo: nil, repeats: true)
        
    }
    
    
    // 7. JS 消息回调
//        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//            if message.name == "starAppVPN"
//            {
//                print("Received message from JS: \(message.body)")
//                if let body = message.body as? [String: Any] {
//                            let entryNodes = body["entryNodes"] as? String ?? ""
//                            let egressNodes = body["egressNodes"] as? String ?? ""
//                            let privateKey = body["privateKey"] as? String ?? ""
//                            
//                            let userDefaults = UserDefaults(suiteName: "conect")
//                            userDefaults?.set(entryNodes, forKey: "entryNodes")
//                            userDefaults?.set(egressNodes, forKey: "egressNodes")
//                            userDefaults?.set(privateKey, forKey: "privateKey")
//                            userDefaults?.synchronize()
//                            
//                            self.vPNManager.refresh()
//                        } else {
//                            print("Invalid message body format")
//                        }
//                
//            }
//            if message.name == "stopAppVPN"
//            {
//                print("Received message from JS: \(message.body)")
//                self.vPNManager.stopVPN()
//            }
//            
//        }

       
    
   
    
    @objc func handleNodeUpdate(notification: Notification) {
        
        if let userInfo = notification.userInfo
        {
            if let nodeCount = userInfo["当前通知类型"] as? String {
                if nodeCount == "获取所有节点"
                {
                    DispatchQueue.main.async {

                        
                        self.label.stringValue = "当前节点正在连接中，请稍等"

                    
                        for subview in self.regionView.subviews {
                            subview.removeFromSuperview()
                        }
                        
                        self.countriesArray = Array(LayerMinus.country)
                        
                        for country in self.countriesArray {
                                   let button = NSButton(title: country, target: self, action: #selector(self.buttonClicked(_:)))
                                   button.bezelStyle = .rounded  // 按钮样式
                                   
                                    let index = self.countriesArray.firstIndex(of: country) ?? 0
                                   button.tag = index // 给按钮设置唯一标识
                                   if country == "AT" {
                                       button.title = "奥地利 (Austria)"
                                   }
                                   
                                   
                                   if country == "AU" {
                                       button.title = "澳大利亚 (Australia)"
                                   }
                                   
                                   
                                   if country == "CA" {
                                       button.title = "加拿大 (Canada)"
                                   }
                                   
                                   
                                   if country == "CH" {
                                       button.title = "瑞士 (Switzerland)"
                                   }
                                   
                                   
                                   if country == "CN" {
                                       button.title = "中国 (China)"
                                   }
                                   
                                   if country == "DE" {
                                       button.title = "德国 (Germany)"
                                   }
                                   
                                   
                                   
                                   if country == "ES" {
                                       button.title = "西班牙 (Spain)"
                                   }
                                   if country == "GB" {
                                       button.title = "英国 (United Kingdom)"
                                   }
                                   if country == "JP" {
                                       button.title = "日本 (Japan)"
                                   }
                                   if country == "SG" {
                                       button.title = "新加坡 (Singapore)"
                                   }
                                   if country == "US" {
                                       button.title = "美国 (United States)"
                                   }
                                   let buttonWidht : Int = 180
                                   let buttonheight : Int = 30
                                   
                                   if index < 4
                                   {
                                       button.frame = CGRect(x: index*buttonWidht , y: 0, width: buttonWidht, height: buttonheight)
                                   }else if (index >= 4 && index < 8){
                                       // 条件2 为 true 时执行的代码
                                       
                                       
                                       button.frame = CGRect(x: CGFloat(index - 4) * CGFloat(buttonWidht),
                                                                y: CGFloat(buttonheight + 5),
                                                                width: CGFloat(buttonWidht),
                                                                height: CGFloat(buttonheight))
                                       
            //                           button.frame = CGRect(x: CGFloat(index - 4) * CGFloat(buttonWidth) , y: buttonheight + 5, width: buttonWidht, height: buttonheight)
                                       
                                   } else {
            //                           button.frame = CGRect(x: (index - 8) *buttonWidht , y: buttonheight*2 + 5, width: buttonWidht, height: buttonheight)
                                       
                                       button.frame = CGRect(x: CGFloat(index - 8) * CGFloat(buttonWidht),
                                                                y: CGFloat(buttonheight * 2 + 5),
                                                                width: CGFloat(buttonWidht),
                                                                height: CGFloat(buttonheight))
                                       
                                       // 以上条件都不满足时执行的代码
                                   }
                                  
                                   
                                   self.regionView.addSubview(button)
                               }
                        
                        
                        
                        
                    }

                }
                
                
                if nodeCount == "切换区域成功"
                {
                    
                    DispatchQueue.main.async {
                        self.label.stringValue = "当前状态:切换区域成功，等待节点连接"
                        
//                        self.indexChangeUS = "切换节点成功"
                        
                    }
                    
                }
                if nodeCount == "允许上网"
                {
                    
                    DispatchQueue.main.async {
                        
                        self.loadingHUD?.hide()
                        self.label.stringValue = "当前状态:网络已保护，请放心使用！"
                        
                      
                        
                        if self.indexChangeUS == "切换节点"
                        {
                            if self.vpnbutton.title == "启动VPN"
                            {
                                //                                VPNManager.shared.stopVPN()
                                
                                self.label.stringValue = "当前状态:网络已保护，请放心使用！点击下方启动VPN按钮"
                                
                            }
                        }
                        
                        
                        if self.indexChangeUS == "正在切换节点"
                        {
                            if self.vpnbutton.title == "启动VPN"
                            {
//                                VPNManager.shared.stopVPN()
                                
                                self.label.stringValue = "当前状态:网络已保护，请放心使用！点击下方启动VPN按钮"
                                
                            }
                            else
                            {
                                
                                self.indexChangeUS = "已启动"
                                
//                                VPNManager.shared.refresh()
                                self.label.stringValue = "当前状态:网络已保护，请放心使用！请重新启动VPN"
                            }
                        }
                        
                    }
                    
                }
                
                if nodeCount == "节点数量"
                {
                    if let nodeCount1 = userInfo["节点"] as? String {
                            DispatchQueue.main.async {
                            
                                self.loadingHUD?.label.stringValue = "当前可用的节点数量\(nodeCount1)"
                            }
                    }
                    
                }
                if nodeCount == "网络连接失败"
                {
                    
                    DispatchQueue.main.async {
                        
                        
                        if userInfo["重试"] is String {
                            if self.index == 2
                            {
                               
                                    
                                self.loadingHUD?.hide()
                                self.label.stringValue = "当前状态:网络异常，请检查当前网络，如果网络没问题，请点击下方重新连接节点按钮！"
                            }
                            else
                            {
                                self.loadingHUD?.hide()
                                self.reconnectcurrentNode();
                                self.index = 2;
                            }
                                
                        }
                        else
                        {
                            self.loadingHUD?.hide()
                            self.label.stringValue = "当前状态:网络异常，请检查当前网络，如果网络没问题，请点击下方重新连接节点按钮！"
                        }
                        
                        
                        
                        
                        
                    }
                    
                }
                
                
            }
        }
        
       
       
        // 此处可更新 UI 或其他处理
    }
    // 按钮点击事件
       @objc func buttonClicked(_ sender: NSButton) {
           print("点击了按钮: \(sender.title)")
       
           
           
           
           DispatchQueue.main.async{
               
               self.indexChangeUS = "正在切换节点"
               
               self.vPNManager.stopVPN()
               self.vpnbutton.title = "启动VPN"
               self.loadingHUD = LoadingHUD(message: "正在切换区域请稍等……")
               self.loadingHUD?.show(in: self.view.window!)
               
//               self.showLoadingHUD(message: "正在切换区域请稍等……")
               let country = self.countriesArray[sender.tag];
               self.countryIndex = country;
//               WebViewManager.shared.layerMinus.setupEgressNodes(country: country)
               
               self.layerMinus.setupEgressNodes(country: country)
               
               self.inputTextField.stringValue = "当前节点区域 \(sender.title)"
           }
           
       }
    
    @objc func reconnectcurrentNode() {
      
        self.loadingHUD = LoadingHUD(message: "正在重新加载当前区域所有节点……")
        self.loadingHUD?.show(in: self.view.window!)
        
//        self.layerMinus.startInVPN(privateKey: self.layerMinus.privateKeyAromed, entryNodes: self.layerMinus.entryNodes, egressNodes: self.layerMinus.egressNodes)
        self.layerMinus.testRegion()
        
//        WebViewManager.shared.layerMinus.testRegion()
    }
    
    func adjustLabelFontSize(toFit text: String) {
            let fixedWidth: CGFloat = 300 // 固定宽度
            var fontSize: CGFloat = 24 // 初始字体大小
            
            while fontSize > 0 {
                let font = NSFont.systemFont(ofSize: fontSize)
                let size = (text as NSString).size(withAttributes: [.font: font])
                
                if size.width <= fixedWidth {
                    break
                }
                fontSize -= 1 // 减小字体
            }
            
            label.font = NSFont.systemFont(ofSize: fontSize) // 应用新的字体大小
        }
    
    @objc func allupdatenode() {
//        refresh()
        
        self.loadingHUD = LoadingHUD(message: "正在重新加载所有节点……")
        self.loadingHUD?.show(in: self.view.window!)
        
        LayerMinus.allNodes.removeAll()
        LayerMinus.country.removeAll()
        
        LayerMinus.currentScanNode = 100
        self.layerMinus.scanAll_nodesapp()
        
//        WebViewManager.shared.layerMinus.allnodeupdate()
    }
    
    
    //      Start VPN
    @objc func testJS() {
        let contry = inputTextField.stringValue
        WebViewManager.shared.layerMinus.setupEgressNodes(country: contry)
        
    }
    
    func updateConnectionNodes(egressNodes: [String], entryNodes: [String], privateKey: String) {
      
            // 调用 putNodes 更新节点
        //localServer?.putNodes(entryNodes: entryNodes, egressNodes: egressNodes, privateKey: privateKey)
        
    }
    
    
    
    @objc func startVPN() {
        print("启动")
        if vpnbutton.title == "启动VPN"
        {
//            打开vpn
            
            vpnbutton.title = "关闭VPN"
            self.vPNManager.refresh()
            
            
        }
        else
        {
            
            vpnbutton.title = "启动VPN"
            self.vPNManager.stopVPN()
//            准备好了 启动vpn
        }
        
        
    }
    
    
    
    
    
    
    
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @objc func getVPNConfigurationStatus() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("Failed to load VPN configurations: \(error.localizedDescription)")
                return
            }

            guard let managers = managers else {
                print("No VPN configurations found")
                return
            }

            for manager in managers {
//                print("VPN configuration: \(manager.localizedDescription ?? "Unknown")")
//                print("Status: \(manager.connection.status)")
                if manager.localizedDescription == "CoNET VPN"
                {
                   
                        NotificationCenter.default.post(
                            name: Notification.Name("VPNStatusChanged"),
                            object: manager.connection.status
                        )
                    
                    
                    
                }
                
                
                
            }
        }
    }
}

extension Data {
    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
    
    
    
}
// MARK: - WKNavigationDelegate
extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView content loaded successfully.")
//        self.loadingHUD?.hide()
    }
}
