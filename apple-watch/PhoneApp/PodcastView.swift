import SwiftUI
import FanControlCore

struct PodcastView: View {
    @ObservedObject private var player = PodcastPlayer.shared
    @State private var search = ""
    private var episodes: [PodcastEpisode] {
        player.queue.episodes.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            Section("Current episode") {
                if let episode = player.queue.current {
                    Text(episode.title).font(.headline)
                    Text("\(PodcastTile.time(player.position)) / \(PodcastTile.time(player.duration))").monospacedDigit()
                    HStack {
                        Button { player.perform(.backward15) } label: { Image(systemName: "gobackward.15") }.accessibilityLabel("Back 15 seconds")
                        Spacer()
                        Button(player.playing ? "Pause" : "Play") { player.perform(player.playing ? .pause : .play) }
                        Spacer()
                        Button { player.perform(.forward15) } label: { Image(systemName: "goforward.15") }.accessibilityLabel("Forward 15 seconds")
                    }.buttonStyle(.borderless).disabled(player.busy)
                    Button("Mark Complete") { player.perform(.complete) }.disabled(player.busy)
                }
                Text(player.status).font(.caption).foregroundStyle(.secondary)
                Text("\(player.queue.window.filter { player.downloaded.contains($0.id) }.count) of \(player.queue.window.count) upcoming episodes downloaded")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Retry downloads") { player.replenish(retry: true) }
            }
            ForEach(PodcastEpisode.seriesOrder, id: \.self) { series in
                let members = episodes.filter { $0.series == series }
                if !members.isEmpty {
                    Section(series) {
                        if series == "Films" {
                            ForEach(members) { episode in episodeRow(episode) }
                        } else {
                            ForEach(Array(Set(members.compactMap(\.season))).sorted(), id: \.self) { season in
                                DisclosureGroup("Season \(season)") {
                                    ForEach(members.filter { $0.season == season }) { episode in episodeRow(episode) }
                                }
                            }
                        }
                    }
                }
            }
            if player.queue.episodes.isEmpty {
                Button(player.refreshing ? "Loading episodes…" : "Load episodes") { Task { await player.refresh() } }.disabled(player.refreshing)
            }
        }
        .navigationTitle("Mission Log")
        .searchable(text: $search, prompt: "Find an episode")
        .refreshable { await player.refresh() }
        .task { await player.refresh() }
    }
    private func episodeRow(_ episode: PodcastEpisode) -> some View {
        Button { player.select(episode) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title).foregroundStyle(.primary)
                    if let history = player.queue.history[episode.id] {
                        if history.completed { Label("Played", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
                        else if history.position > 0 { Text("In progress · \(PodcastTile.time(history.position))").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Spacer()
                if player.downloaded.contains(episode.id) { Image(systemName: "arrow.down.circle.fill").accessibilityLabel("Downloaded") }
                if player.queue.currentID == episode.id { Image(systemName: "play.circle").accessibilityLabel("Current episode") }
            }
        }.disabled(player.busy)
    }
}
