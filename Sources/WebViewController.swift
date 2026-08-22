import Cocoa
import WebKit

final class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    
    override func loadView() {
        let config = createWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = AppConfiguration.safariUserAgent
        webView.allowsBackForwardNavigationGestures = true
        
        // Prevent background view occlusion throttling
        webView.wantsLayer = true
        
        self.view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSleepWakeObservers()
        loadNetflix()
    }
    
    deinit {
        if let obs = sleepObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = wakeObserver { NotificationCenter.default.removeObserver(obs) }
        AppState.shared.endPlaybackActivity()
    }
    
    private func createWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Persist cookies, auth session, IndexedDB, local storage
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Enable HTML5 element fullscreen (crucial for Netflix custom player fullscreen)
        let preferences = WKPreferences()
        preferences.isElementFullscreenEnabled = true
        preferences.setValue(true, forKey: "developerExtrasEnabled")
        configuration.preferences = preferences
        
        // Media playback policies
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webpagePreferences
        
        return configuration
    }
    
    func loadNetflix() {
        let request = URLRequest(url: AppConfiguration.netflixHomeURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30.0)
        webView.load(request)
    }
    
    func reload() {
        webView.reload()
    }
    
    // MARK: - Sleep / Wake Lifecycle Handling
    
    private func setupSleepWakeObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        
        sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWillSleep()
        }
        
        wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemDidWake()
        }
    }
    
    private func handleSystemWillSleep() {
        AppState.shared.endPlaybackActivity()
        // Gracefully pause HTML5 video to avoid audio/video buffer desync
        let pauseScript = "if (document.querySelector('video')) { document.querySelector('video').pause(); }"
        webView.evaluateJavaScript(pauseScript, completionHandler: nil)
    }
    
    private func handleSystemDidWake() {
        if let url = webView.url, url.absoluteString.contains("/watch/") {
            AppState.shared.beginPlaybackActivity()
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let host = url.host?.lowercased() ?? ""
        
        // Keep Netflix & auth domains internal; forward third-party external links to default browser
        if host.contains("netflix.com") || host.contains("nflxvideo.net") || host.contains("nflximg.net") || host.contains("nflxext.com") || host.isEmpty {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url else { return }
        
        if currentURL.absoluteString.contains("/watch/") {
            AppState.shared.currentPlaybackState = .active
            AppState.shared.beginPlaybackActivity()
        } else {
            AppState.shared.currentPlaybackState = .idle
            AppState.shared.endPlaybackActivity()
        }
    }
    
    // MARK: - Process Recovery
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppState.shared.crashReloadCount += 1
        AppState.shared.endPlaybackActivity()
        NSLog("[NetflixNative] WebContent process terminated. Recovering (attempt \(AppState.shared.crashReloadCount))...")
        
        // Automatic recovery after WebKit process kill/crash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.webView.reload()
        }
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Route popup requests into the current webview
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
