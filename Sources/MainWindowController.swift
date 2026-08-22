import Cocoa

final class MainWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        // Silence macOS alert beep for media and navigation keys handled asynchronously by WebKit
        switch event.keyCode {
        case 49,                 // Spacebar (Play/Pause)
             123, 124, 125, 126, // Arrow keys (Left, Right, Down, Up)
             3,                  // F (Fullscreen)
             46,                 // M (Mute)
             1,                  // S (Skip Intro)
             40:                 // K (Play/Pause)
            return
        default:
            super.keyDown(with: event)
        }
    }
}

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let webViewController = WebViewController()
    
    init() {
        let window = MainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
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
