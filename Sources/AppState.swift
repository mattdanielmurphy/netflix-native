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

final class AppState: ObservableObject {
    static let shared = AppState()
    
    var currentPlaybackState: PlaybackState = .idle
    var powerAssertionToken: NSObjectProtocol?
    var crashReloadCount: Int = 0
    
    // Subtitle & Dialogue Waterfall State
    var dialogueHistory: [SubtitleCue] = []
    var activeCue: SubtitleCue?
    var isOverlayVisible: Bool = false
    var currentSnapshot: PlayerSnapshot?
    var connectedClientsCount: Int = 0
    var serverPort: UInt16 = 8765
    
    // Callback hooks for UI / WebViewController updates
    var onDialogueHistoryChanged: (([SubtitleCue]) -> Void)?
    var onActiveCueChanged: ((SubtitleCue?) -> Void)?
    var onOverlayVisibilityChanged: ((Bool) -> Void)?
    var onClientCountChanged: ((Int) -> Void)?
    var onSeekRequested: ((Double) -> Void)?
    
    private let maxHistoryEntries: Int = 250
    
    private init() {}
    
    func appendCue(_ cue: SubtitleCue) {
        // Prevent duplicate consecutive lines
        if let last = dialogueHistory.last, last.text == cue.text {
            // Update end time if current cue is active
            activeCue = cue
            onActiveCueChanged?(cue)
            return
        }
        
        dialogueHistory.append(cue)
        if dialogueHistory.count > maxHistoryEntries {
            dialogueHistory.removeFirst(dialogueHistory.count - maxHistoryEntries)
        }
        activeCue = cue
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onDialogueHistoryChanged?(self.dialogueHistory)
            self.onActiveCueChanged?(cue)
        }
    }
    
    func clearHistory() {
        dialogueHistory.removeAll()
        activeCue = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onDialogueHistoryChanged?([])
            self.onActiveCueChanged?(nil)
        }
    }
    
    func toggleOverlay() {
        isOverlayVisible.toggle()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onOverlayVisibilityChanged?(self.isOverlayVisible)
        }
    }
    
    func setOverlayVisible(_ visible: Bool) {
        isOverlayVisible = visible
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onOverlayVisibilityChanged?(visible)
        }
    }
    
    func requestSeek(to seconds: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.onSeekRequested?(seconds)
        }
    }
    
    func updateClientCount(_ count: Int) {
        connectedClientsCount = count
        DispatchQueue.main.async { [weak self] in
            self?.onClientCountChanged?(count)
        }
    }
    
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

