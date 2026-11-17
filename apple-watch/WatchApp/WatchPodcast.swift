import Foundation
import SwiftUI
import WatchConnectivity
import FanControlCore

@MainActor final class WatchPodcast: ObservableObject {
    static let shared = WatchPodcast()
    @Published private(set) var snapshot: PodcastSnapshot?
    @Published private(set) var pending: PodcastCommand?
    @Published private(set) var confirmed = false
    @Published private(set) var error = ""
    private var scope: String?
    private var visible = false
    private var timeout: Task<Void, Never>?
    private var requestID: UUID?
    init() {
        if let data = UserDefaults.standard.data(forKey: "podcastSnapshot"),
           let saved = try? JSONDecoder().decode(PodcastSnapshot.self, from: data) { snapshot = saved }
        scope = UserDefaults.standard.string(forKey: "podcastScope")
    }
    func receive(_ message: [String: Any], live: Bool = false) {
        guard let c = Vault.load(), message["podcast_watch_id"] as? String == c.watch_id else { return }
        resetScope(c.watch_id)
        if let index = message["podcast_index"] as? Int {
            UserDefaults.standard.set(index, forKey: "podcastIndex")
        }
        guard let data = message["podcast"] as? Data,
              let next = try? JSONDecoder().decode(PodcastSnapshot.self, from: data) else { return }
        guard pending == nil, next.sequence > (snapshot?.sequence ?? -1) else { return }
        snapshot = next
        if pending == nil { confirmed = live && visible }
        UserDefaults.standard.set(data, forKey: "podcastSnapshot")
    }
    private func resetScope(_ watchID: String) {
        guard scope != watchID else { return }
        clear(); scope = watchID; UserDefaults.standard.set(watchID, forKey: "podcastScope")
    }
    func enter(play: Bool = false) {
        if let c = Vault.load() { resetScope(c.watch_id) }
        visible = true; confirmed = false
        if play { send(.playCurrent) } else { refresh() }
    }
    func leave() {
        visible = false; timeout?.cancel(); timeout = nil; pending = nil; requestID = nil; confirmed = false
        // A delivered phone action is never replayed; leaving only cancels UI work.
    }
    func clear() {
        leave(); snapshot = nil; scope = nil; error = ""
        for key in ["podcastSnapshot", "podcastScope", "podcastIndex"] { UserDefaults.standard.removeObject(forKey: key) }
    }
    func refresh() { send(.state) }
    func send(_ action: PodcastAction, position: Double? = nil) {
        guard pending == nil, let c = Vault.load() else { return }
        resetScope(c.watch_id)
        let session = WCSession.default
        error = ""; confirmed = false
        let projection = action == .backward15 ? max(0, (snapshot?.position ?? 0) - 15)
            : action == .forward15 ? min(snapshot?.duration ?? .greatestFiniteMagnitude, (snapshot?.position ?? 0) + 15) : position
        let command = PodcastCommand(action: action, episodeID: snapshot?.episode?.id, revision: snapshot?.revision, position: projection)
        guard session.activationState == .activated, session.isReachable,
              let raw = try? JSONEncoder().encode(command) else {
            error = "Not confirmed. Open Fan Control on iPhone and retry."; return
        }
        pending = command; requestID = command.id
        timeout?.cancel()
        timeout = Task {
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            fail(command.id, scope: c.watch_id)
        }
        session.sendMessage(["podcast_command": raw, "watch_id": c.watch_id], replyHandler: { value in
            Task { @MainActor in
                guard self.visible, self.requestID == command.id, Vault.load()?.watch_id == c.watch_id,
                      let raw = value["podcast_reply"] as? Data,
                      let reply = try? JSONDecoder().decode(PodcastReply.self, from: raw), reply.commandID == command.id else { return }
                self.timeout?.cancel(); self.pending = nil; self.requestID = nil
                // Never roll back a newer phone observation with an older receipt.
                guard reply.snapshot.sequence >= (self.snapshot?.sequence ?? -1) else { self.confirmed = false; self.error = "Not confirmed. Retry."; return }
                self.snapshot = reply.snapshot
                self.confirmed = reply.confirms(command)
                self.error = self.confirmed ? "" : reply.error ?? "Not confirmed. Retry."
                if let data = try? JSONEncoder().encode(reply.snapshot) { UserDefaults.standard.set(data, forKey: "podcastSnapshot") }
            }
        }, errorHandler: { _ in Task { @MainActor in self.fail(command.id, scope: c.watch_id) } })
    }
    private func fail(_ id: UUID, scope: String) {
        guard requestID == id, Vault.load()?.watch_id == scope else { return }
        timeout?.cancel(); pending = nil; requestID = nil; confirmed = false
        error = "Not confirmed. Retry."
    }
    var displayedPosition: Double { pending?.position ?? snapshot?.position ?? 0 }
    var displayedPlaying: Bool {
        if let action = pending?.action {
            if action == .play || action == .playCurrent { return true }
            if action == .pause || action == .complete { return false }
        }
        return snapshot?.playing == true
    }
}

struct PodcastPlaybackView: View {
    let onSwipe: (Int) -> Void
    @ObservedObject private var podcast = WatchPodcast.shared
    private var color: Color { podcast.confirmed && podcast.pending == nil ? .mint : .gray }
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 8) {
                Text("Mission Log").font(.caption)
                Text(podcast.snapshot?.episode?.title ?? "Choose next episode on iPhone").font(.headline).multilineTextAlignment(.center)
                Text("\(PodcastTile.time(podcast.displayedPosition)) · −\(PodcastTile.time(max(0, (podcast.snapshot?.duration ?? 0) - (podcast.snapshot?.position ?? 0))))")
                    .font(.caption).monospacedDigit()
                HStack {
                    Button { podcast.send(.backward15) } label: { Image(systemName: "gobackward.15") }.accessibilityLabel("Back 15 seconds")
                    Button { podcast.send(podcast.displayedPlaying ? .pause : .playCurrent) } label: {
                        VStack(spacing: 2) {
                            Image(systemName: podcast.displayedPlaying ? "pause.fill" : "play.fill")
                            Text(podcast.displayedPlaying ? "Playing" : podcast.snapshot == nil ? "Play" : "Paused").font(.caption2)
                        }
                    }.accessibilityLabel(podcast.displayedPlaying ? "Pause" : "Play")
                    Button { podcast.send(.forward15) } label: { Image(systemName: "goforward.15") }.accessibilityLabel("Forward 15 seconds")
                }
                Button(podcast.pending?.action == .complete ? "Complete" : "Mark Complete") { podcast.send(.complete) }
                if !podcast.error.isEmpty {
                    Text(podcast.error).font(.caption2).foregroundStyle(.gray)
                    Button("Refresh", action: podcast.refresh)
                } else if let status = podcast.snapshot?.status { Text(status).font(.caption2) }
            }.foregroundStyle(color).tint(color.opacity(0.25)).disabled(podcast.pending != nil).padding(.horizontal, 5)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                .tileSwipe(onSwipe: onSwipe)
        }
        }
    }
}
