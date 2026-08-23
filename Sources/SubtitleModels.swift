import Foundation

public struct SubtitleCue: Identifiable, Codable, Equatable {
    public let id: String
    public let text: String
    public let startTime: Double
    public let endTime: Double
    public let formattedTime: String
    public let timestamp: Double
    
    public init(id: String = UUID().uuidString, text: String, startTime: Double, endTime: Double, formattedTime: String = "", timestamp: Double = Date().timeIntervalSince1970) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.formattedTime = formattedTime.isEmpty ? SubtitleCue.formatSeconds(startTime) : formattedTime
        self.timestamp = timestamp
    }
    
    public static func formatSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

public struct PlayerSnapshot: Codable, Equatable {
    public let currentTime: Double
    public let duration: Double
    public let isPaused: Bool
    public let title: String?
    public let episodeId: String?
    
    public init(currentTime: Double, duration: Double, isPaused: Bool, title: String? = nil, episodeId: String? = nil) {
        self.currentTime = currentTime
        self.duration = duration
        self.isPaused = isPaused
        self.title = title
        self.episodeId = episodeId
    }
}

public struct ServerMessage: Codable {
    public let type: String
    public let cue: SubtitleCue?
    public let history: [SubtitleCue]?
    public let status: PlayerSnapshot?
    public let clientCount: Int?
    public let port: Int?
    
    public init(type: String, cue: SubtitleCue? = nil, history: [SubtitleCue]? = nil, status: PlayerSnapshot? = nil, clientCount: Int? = nil, port: Int? = nil) {
        self.type = type
        self.cue = cue
        self.history = history
        self.status = status
        self.clientCount = clientCount
        self.port = port
    }
}

public struct ClientCommand: Codable {
    public let action: String
    public let time: Double?
    public let seekDelta: Double?
    
    public init(action: String, time: Double? = nil, seekDelta: Double? = nil) {
        self.action = action
        self.time = time
        self.seekDelta = seekDelta
    }
}
