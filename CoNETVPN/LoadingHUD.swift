import Cocoa

class LoadingHUD: NSView {

    let indicator = NSProgressIndicator()
    let label = NSTextField(labelWithString: "")

    init(message: String = "加载中...") {
        super.init(frame: .zero)

        // 设置 HUD 视图
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor

        // HUD 容器
        let hudContainer = NSView()
        hudContainer.wantsLayer = true
        hudContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        hudContainer.layer?.cornerRadius = 10
        hudContainer.translatesAutoresizingMaskIntoConstraints = false

        // 加载指示器
        indicator.style = .spinning
        indicator.controlSize = .large
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        indicator.translatesAutoresizingMaskIntoConstraints = false

        // 文本标签
        label.stringValue = message
        label.alignment = .center
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14)
        label.lineBreakMode = .byWordWrapping // 支持换行
        label.maximumNumberOfLines = 0       // 设置多行显示
        label.translatesAutoresizingMaskIntoConstraints = false

        // 组合 HUD
        hudContainer.addSubview(indicator)
        hudContainer.addSubview(label)
        self.addSubview(hudContainer)

        // 布局约束
        NSLayoutConstraint.activate([
            hudContainer.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            hudContainer.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            hudContainer.widthAnchor.constraint(equalToConstant: 200), // 增加宽度以支持较长文本
            hudContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120), // 最小高度

            indicator.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: hudContainer.topAnchor, constant: 20),

            label.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor, constant: 10), // 左右间距
            label.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(lessThanOrEqualTo: hudContainer.bottomAnchor, constant: -10) // 保持下方间距
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // 显示 HUD
    func show(in window: NSWindow) {
        guard let contentView = window.contentView else { return }
        self.frame = contentView.bounds
        self.autoresizingMask = [.width, .height]
        contentView.addSubview(self)
    }

    // 隐藏 HUD
    func hide() {
        self.removeFromSuperview()
    }

    // 鼠标事件拦截
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        // 拦截鼠标点击，什么都不做
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // 返回自身，确保视图拦截事件
        return self
    }
}
