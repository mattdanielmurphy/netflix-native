import Foundation
import Network
import CryptoKit

final class EmbeddedHTTPServer {
    static let shared = EmbeddedHTTPServer()
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "ca.mattmurphy.netflixnative.server", qos: .userInitiated)
    private var webSocketConnections = [ObjectIdentifier: NWConnection]()
    private let lock = NSLock()
    
    private(set) var boundPort: UInt16 = 8765
    
    private init() {}
    
    func start(port: UInt16 = 8765) {
        stop()
        self.boundPort = port
        
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true
            
            guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
                NSLog("[Server] Invalid port: \(port)")
                return
            }
            
            let nwListener = try NWListener(using: params, on: portEndpoint)
            
            // Set Bonjour advertisement for automatic LAN discovery
            nwListener.service = NWListener.Service(name: "Netflix Native Subtitles", type: "_netflixsub._tcp")
            
            nwListener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    NSLog("[Server] Listening on http://0.0.0.0:\(self.boundPort)")
                    AppState.shared.serverPort = self.boundPort
                case .failed(let error):
                    NSLog("[Server] Listener failed with error: \(error). Retrying on next port...")
                    if self.boundPort < 8775 {
                        self.start(port: self.boundPort + 1)
                    }
                default:
                    break
                }
            }
            
            nwListener.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection)
            }
            
            self.listener = nwListener
            nwListener.start(queue: queue)
        } catch {
            NSLog("[Server] Failed to initialize listener: \(error)")
            if port < 8775 {
                start(port: port + 1)
            }
        }
    }
    
    func stop() {
        lock.lock()
        for (_, conn) in webSocketConnections {
            conn.cancel()
        }
        webSocketConnections.removeAll()
        lock.unlock()
        
        listener?.cancel()
        listener = nil
        AppState.shared.updateClientCount(0)
    }
    
    func broadcastCue(_ cue: SubtitleCue) {
        let msg = ServerMessage(type: "cue", cue: cue)
        broadcast(message: msg)
    }
    
    func broadcastHistory(_ history: [SubtitleCue]) {
        let msg = ServerMessage(type: "history", history: history)
        broadcast(message: msg)
    }
    
    func broadcastClear() {
        let msg = ServerMessage(type: "clear")
        broadcast(message: msg)
    }
    
    private func broadcast(message: ServerMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        let frame = makeWebSocketTextFrame(data: data)
        
        lock.lock()
        let connections = Array(webSocketConnections.values)
        lock.unlock()
        
        for conn in connections {
            conn.send(content: frame, completion: .contentProcessed({ _ in }))
        }
    }
    
    // MARK: - Incoming Connection Handling
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        readHTTPRequest(connection)
    }
    
    private func readHTTPRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            guard let self = self, let data = data, let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            let lines = requestString.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else {
                connection.cancel()
                return
            }
            
            let parts = requestLine.components(separatedBy: " ")
            let path = parts.count > 1 ? parts[1] : "/"
            
            // Check for WebSocket upgrade
            var isWebSocketUpgrade = false
            var wsKey = ""
            for line in lines {
                let lower = line.lowercased()
                if lower.contains("upgrade: websocket") {
                    isWebSocketUpgrade = true
                } else if lower.hasPrefix("sec-websocket-key:") {
                    let keyParts = line.components(separatedBy: ":")
                    if keyParts.count > 1 {
                        wsKey = keyParts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            if isWebSocketUpgrade && !wsKey.isEmpty {
                self.upgradeToWebSocket(connection: connection, wsKey: wsKey)
            } else {
                self.serveHTTPResponse(connection: connection, path: path)
            }
        }
    }
    
    private func serveHTTPResponse(connection: NWConnection, path: String) {
        let htmlPath = Bundle.main.path(forResource: "SecondaryDisplayClient", ofType: "html") ??
                       "/Users/matt/projects/netflix-native/Resources/SecondaryDisplayClient.html"
        
        var bodyData = Data()
        if let fileContent = try? Data(contentsOf: URL(fileURLWithPath: htmlPath)) {
            bodyData = fileContent
        } else {
            let fallbackHTML = "<html><body style='background:#111;color:#fff;font-family:sans-serif;'><h2>Netflix Native Dialogue Stream</h2><p>Display client resource not found.</p></body></html>"
            bodyData = fallbackHTML.data(using: .utf8) ?? Data()
        }
        
        var response = "HTTP/1.1 200 OK\r\n"
        response += "Content-Type: text/html; charset=utf-8\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "Connection: close\r\n"
        response += "Access-Control-Allow-Origin: *\r\n\r\n"
        
        var responseData = response.data(using: .utf8) ?? Data()
        responseData.append(bodyData)
        
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func upgradeToWebSocket(connection: NWConnection, wsKey: String) {
        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = wsKey + magicString
        let hash = Insecure.SHA1.hash(data: combined.data(using: .utf8) ?? Data())
        let acceptKey = Data(hash).base64EncodedString()
        
        let handshakeResponse = "HTTP/1.1 101 Switching Protocols\r\n" +
                                "Upgrade: websocket\r\n" +
                                "Connection: Upgrade\r\n" +
                                "Sec-WebSocket-Accept: \(acceptKey)\r\n\r\n"
        
        connection.send(content: handshakeResponse.data(using: .utf8), completion: .contentProcessed({ [weak self] _ in
            guard let self = self else { return }
            let id = ObjectIdentifier(connection)
            self.lock.lock()
            self.webSocketConnections[id] = connection
            let count = self.webSocketConnections.count
            self.lock.unlock()
            
            AppState.shared.updateClientCount(count)
            
            // Send initial history
            let history = AppState.shared.dialogueHistory
            if !history.isEmpty {
                if let historyData = try? JSONEncoder().encode(ServerMessage(type: "history", history: history)) {
                    let frame = self.makeWebSocketTextFrame(data: historyData)
                    connection.send(content: frame, completion: .contentProcessed({ _ in }))
                }
            }
            
            self.readWebSocketFrames(connection: connection)
        }))
    }
    
    private func readWebSocketFrames(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, data.count >= 2, error == nil else {
                self?.removeConnection(connection)
                return
            }
            
            let bytes = [UInt8](data)
            let opcode = bytes[0] & 0x0F
            
            // Opcode 8 is Connection Close
            if opcode == 0x08 {
                self.removeConnection(connection)
                return
            }
            
            // Opcode 1 is Text Frame
            if opcode == 0x01 {
                var payloadStart = 2
                let isMasked = (bytes[1] & 0x80) != 0
                var payloadLength = UInt64(bytes[1] & 0x7F)
                
                if payloadLength == 126 {
                    payloadLength = UInt64(bytes[2]) << 8 | UInt64(bytes[3])
                    payloadStart = 4
                } else if payloadLength == 127 {
                    payloadStart = 10
                }
                
                if isMasked && bytes.count >= payloadStart + 4 {
                    let mask = Array(bytes[payloadStart..<payloadStart+4])
                    payloadStart += 4
                    let payloadBytes = Array(bytes[payloadStart..<min(bytes.count, payloadStart + Int(payloadLength))])
                    var unmasked = [UInt8](repeating: 0, count: payloadBytes.count)
                    for i in 0..<payloadBytes.count {
                        unmasked[i] = payloadBytes[i] ^ mask[i % 4]
                    }
                    if let string = String(bytes: unmasked, encoding: .utf8),
                       let commandData = string.data(using: .utf8),
                       let command = try? JSONDecoder().decode(ClientCommand.self, from: commandData) {
                        self.handleClientCommand(command)
                    }
                }
            }
            
            self.readWebSocketFrames(connection: connection)
        }
    }
    
    private func handleClientCommand(_ command: ClientCommand) {
        switch command.action {
        case "seek":
            if let time = command.time {
                AppState.shared.requestSeek(to: time)
            }
        default:
            break
        }
    }
    
    private func removeConnection(_ connection: NWConnection) {
        lock.lock()
        let id = ObjectIdentifier(connection)
        webSocketConnections.removeValue(forKey: id)
        let count = webSocketConnections.count
        lock.unlock()
        
        connection.cancel()
        AppState.shared.updateClientCount(count)
    }
    
    private func makeWebSocketTextFrame(data: Data) -> Data {
        var frame = Data()
        frame.append(0x81) // FIN + Text opcode
        let count = data.count
        if count <= 125 {
            frame.append(UInt8(count))
        } else if count <= 65535 {
            frame.append(126)
            frame.append(UInt8((count >> 8) & 0xFF))
            frame.append(UInt8(count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((count >> (i * 8)) & 0xFF))
            }
        }
        frame.append(data)
        return frame
    }
}
