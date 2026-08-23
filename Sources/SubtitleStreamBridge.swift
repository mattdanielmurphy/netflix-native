import Cocoa
import WebKit

final class SubtitleStreamBridge: NSObject, WKScriptMessageHandler {
    weak var webViewController: WebViewController?
    
    init(webViewController: WebViewController? = nil) {
        self.webViewController = webViewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "subtitleStream",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else {
            return
        }
        
        switch type {
        case "cue":
            handleCueMessage(dict)
        case "toggleOverlay":
            AppState.shared.toggleOverlay()
        case "seeked":
            if let seconds = dict["currentTime"] as? Double {
                AppState.shared.handleSeeked(at: seconds)
            }
        case "urlChanged":
            if let isWatch = dict["isWatch"] as? Bool, !isWatch {
                AppState.shared.clearHistory()
                AppState.shared.setOverlayVisible(false)
            }
        default:
            break
        }
    }
    
    private func handleCueMessage(_ dict: [String: Any]) {
        guard let text = dict["text"] as? String, !text.isEmpty,
              let startTime = dict["startTime"] as? Double else {
            return
        }
        
        let id = dict["id"] as? String ?? UUID().uuidString
        let endTime = dict["endTime"] as? Double ?? (startTime + 3.5)
        let formattedTime = dict["formattedTime"] as? String ?? SubtitleCue.formatSeconds(startTime)
        let timestamp = dict["timestamp"] as? Double ?? Date().timeIntervalSince1970
        
        let cue = SubtitleCue(
            id: id,
            text: text,
            startTime: startTime,
            endTime: endTime,
            formattedTime: formattedTime,
            timestamp: timestamp
        )
        
        AppState.shared.appendCue(cue)
    }
}
