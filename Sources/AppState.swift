import Foundation
import AppKit

struct AppConfiguration {
    static let netflixHomeURL = URL(string: "https://www.netflix.com")!
    static let netflixHost = "netflix.com"
    static let appWindowAutosaveName = "NetflixNativeWindowPosition"
    
    // Clean modern Safari desktop user agent to ensure FairPlay + 4K HEVC pipeline delivery
    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
}

enum PlaybackState {
    case idle
    case active
    case terminated
}

final class AppState {
    static let shared = AppState()
    
    var currentPlaybackState: PlaybackState = .idle
    var powerAssertionToken: NSObjectProtocol?
    var crashReloadCount: Int = 0
    
    private init() {}
    
    func beginPlaybackActivity() {
        guard powerAssertionToken == nil else { return }
        powerAssertionToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Netflix 4K Playback Active"
        )
    }
    
    func endPlaybackActivity() {
        if let token = powerAssertionToken {
            ProcessInfo.processInfo.endActivity(token)
            powerAssertionToken = nil
        }
    }
}
