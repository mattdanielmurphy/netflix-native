import Cocoa

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let webViewController = WebViewController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1280, height: 800),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.isReleasedWhenClosed = false
        setupWindowAppearance(window)
        window.delegate = self
        window.contentViewController = webViewController
        window.center()
        window.setFrameAutosaveName(AppConfiguration.appWindowAutosaveName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindowAppearance(_ window: NSWindow) {
        window.title = "Netflix"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 640, height: 480)
        
        // Dark visual appearance to match Netflix
        window.appearance = NSAppearance(named: .darkAqua)
    }
    
    func reloadWebView() {
        webViewController.reload()
    }
    
    func navigateHome() {
        webViewController.loadNetflix()
    }
}
