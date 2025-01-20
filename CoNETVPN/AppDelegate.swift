import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windowController: NSWindowController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 获取主窗口控制器
        if let mainWindowController = NSApplication.shared.windows.first?.windowController {
            self.windowController = mainWindowController
        } else {
            print("Main window not found")
        }
    }

    // 点击 Dock 图标时处理
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { // 如果没有可见窗口
            windowController?.window?.makeKeyAndOrderFront(self) // 重新显示窗口
            NSApp.activate(ignoringOtherApps: true) // 激活应用程序
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 确保关闭窗口时应用不会退出
    }
}
