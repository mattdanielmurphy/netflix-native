import Cocoa
import WebKit
import SwiftUI

final class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var subtitleBridge: SubtitleStreamBridge!
    private var overlayHostingView: NSHostingView<DialogueWaterfallSwiftUIView>?
    
    override func loadView() {
        let config = createWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = AppConfiguration.safariUserAgent
        webView.allowsBackForwardNavigationGestures = true
        
        // Prevent background view occlusion throttling
        webView.wantsLayer = true
        
        let containerView = NSView()
        containerView.wantsLayer = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        setupDialogueOverlay(in: containerView)
        self.view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSleepWakeObservers()
        setupAppStateHooks()
        loadNetflix()
    }
    
    deinit {
        if let obs = sleepObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = wakeObserver { NotificationCenter.default.removeObserver(obs) }
        AppState.shared.endPlaybackActivity()
    }
    
    private func setupAppStateHooks() {
        AppState.shared.onSeekRequested = { [weak self] seconds in
            self?.seekVideo(to: seconds)
        }
        
        AppState.shared.onOverlayVisibilityChanged = { [weak self] visible in
            self?.updateOverlayVisibility(visible)
        }
        
        AppState.shared.onDialogueHistoryChanged = { cues in
            if let last = cues.last {
                EmbeddedHTTPServer.shared.broadcastCue(last)
            }
        }
    }
    
    private func setupDialogueOverlay(in container: NSView) {
        let hostingView = NSHostingView(rootView: DialogueWaterfallSwiftUIView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.isHidden = true
        hostingView.layer?.opacity = 0.0
        
        container.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -40),
            hostingView.widthAnchor.constraint(equalToConstant: 340)
        ])
        
        self.overlayHostingView = hostingView
    }
    
    private func updateOverlayVisibility(_ visible: Bool) {
        guard let overlay = overlayHostingView else { return }
        
        if visible {
            overlay.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                overlay.animator().alphaValue = 1.0
            }
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                overlay.animator().alphaValue = 0.0
            }, completionHandler: {
                if !AppState.shared.isOverlayVisible {
                    overlay.isHidden = true
                }
            })
        }
    }
    
    func seekVideo(to seconds: Double) {
        let js = "if (window.__netflixNativeSeek) { window.__netflixNativeSeek(\(seconds)); }"
        webView.evaluateJavaScript(js, completionHandler: nil)
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
        
        let userContentController = WKUserContentController()
        
        // Subtitle & Dialogue Bridge
        subtitleBridge = SubtitleStreamBridge(webViewController: self)
        userContentController.add(subtitleBridge, name: "subtitleStream")
        
        // Spacebar play/pause handler
        let spacebarScriptSource = """
        window.addEventListener('keydown', function(e) {
            if (e.code === 'Space' || e.keyCode === 32) {
                var active = document.activeElement;
                var isInput = active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);
                if (!isInput) {
                    var video = document.querySelector('video');
                    if (video) {
                        e.preventDefault();
                        if (video.paused) {
                            video.play();
                        } else {
                            video.pause();
                        }
                    }
                }
            }
        }, true);
        """
        let spacebarScript = WKUserScript(source: spacebarScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(spacebarScript)
        
        // Subtitle Extractor & Remote Control Script
        let extractorScript = WKUserScript(source: SubtitleScriptInjector.scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(extractorScript)
        
        configuration.userContentController = userContentController
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
        let pauseScript = "if (document.querySelector('video')) { document.querySelector('video').pause(); }"
        webView.evaluateJavaScript(pauseScript, completionHandler: nil)
    }
    
    private func handleSystemDidWake() {
        if let url = webView.url, url.absoluteString.contains("/watch/") {
            AppState.shared.beginPlaybackActivity()
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    private func isInternalDomain(_ host: String) -> Bool {
        let h = host.lowercased()
        if h.isEmpty { return true }
        let allowedDomains = [
            "netflix.com",
            "netflix.net",
            "nflxvideo.net",
            "nflximg.net",
            "nflxext.com",
            "nflxso.net",
            "fast.com",
            "google.com",
            "gstatic.com",
            "recaptcha.net",
            "arkoselabs.com",
            "arkose.com"
        ]
        return allowedDomains.contains { h == $0 || h.hasSuffix("." + $0) }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" || scheme == "blob" || scheme == "data" || scheme == "javascript" {
            decisionHandler(.allow)
            return
        }
        
        guard let targetFrame = navigationAction.targetFrame, targetFrame.isMainFrame else {
            decisionHandler(.allow)
            return
        }
        
        let host = url.host?.lowercased() ?? ""
        if isInternalDomain(host) {
            decisionHandler(.allow)
            return
        }
        
        if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url else { return }
        
        if currentURL.absoluteString.contains("/watch/") {
            AppState.shared.currentPlaybackState = .active
            AppState.shared.beginPlaybackActivity()
        } else {
            AppState.shared.currentPlaybackState = .idle
            AppState.shared.endPlaybackActivity()
            AppState.shared.setOverlayVisible(false)
        }
    }
    
    // MARK: - Process Recovery
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppState.shared.crashReloadCount += 1
        AppState.shared.endPlaybackActivity()
        NSLog("[NetflixNative] WebContent process terminated. Recovering (attempt \(AppState.shared.crashReloadCount))...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.webView.reload()
        }
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                let host = url.host?.lowercased() ?? ""
                if isInternalDomain(host) {
                    webView.load(navigationAction.request)
                } else if navigationAction.navigationType == .linkActivated {
                    NSWorkspace.shared.open(url)
                } else {
                    webView.load(navigationAction.request)
                }
            }
        }
        return nil
    }
}

