import Cocoa
import SwiftUI

struct DialogueBubbleView: View {
    let cue: SubtitleCue
    let isActive: Bool
    let onSeek: (Double) -> Void
    
    var body: some View {
        Button(action: {
            onSeek(cue.startTime)
        }) {
            HStack(alignment: .top, spacing: 10) {
                Text(cue.formattedTime)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? Color.yellow : Color.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                    )
                
                Text(cue.text)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Color.white : Color.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.white.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DialogueWaterfallSwiftUIView: View {
    @State private var cues: [SubtitleCue] = []
    @State private var activeCue: SubtitleCue?
    @State private var searchQuery: String = ""
    
    var filteredCues: [SubtitleCue] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cues
        }
        return cues.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Image(systemName: "captions.bubble.fill")
                    .foregroundColor(.yellow)
                Text("Dialogue Waterfall")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !cues.isEmpty {
                    Text("\(cues.count) lines")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    AppState.shared.setOverlayVisible(false)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.4))
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
                TextField("Filter dialogue...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.gray)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Waterfall dialogue feed
            if filteredCues.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(cues.isEmpty ? "Waiting for dialogue..." : "No matching dialogue")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredCues) { cue in
                                DialogueBubbleView(
                                    cue: cue,
                                    isActive: activeCue?.id == cue.id,
                                    onSeek: { time in
                                        AppState.shared.requestSeek(to: time)
                                    }
                                )
                                .id(cue.id)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: cues.count) { _ in
                        if searchQuery.isEmpty, let last = cues.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Footer Info
            HStack {
                Text("Click line to seek • Press 'D' or scroll up to toggle")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.8))
                Spacer()
                if AppState.shared.connectedClientsCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(AppState.shared.connectedClientsCount) display\(AppState.shared.connectedClientsCount > 1 ? "s" : "")")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
        }
        .frame(width: 340)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                Color.black.opacity(0.75)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
        .onAppear {
            cues = AppState.shared.dialogueHistory
            activeCue = AppState.shared.activeCue
            
            AppState.shared.onDialogueHistoryChanged = { updated in
                self.cues = updated
            }
            AppState.shared.onActiveCueChanged = { active in
                self.activeCue = active
            }
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
