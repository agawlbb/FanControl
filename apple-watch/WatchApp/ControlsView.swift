import SwiftUI
import FanControlCore

struct ControlsView: View {
    @StateObject private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var setup = false
    @State private var entryReady = false
    var body: some View {
        Group {
          if scenePhase != .active || !entryReady {
            Color.black
          } else if model.showingPodcast {
            PodcastPlaybackView()
          } else if model.showingSettings {
            WatchSettingsView(model: model)
          } else if model.device?.panel?.type == "exercise" {
            GeometryReader { geometry in
                VStack(spacing: 4) {
                    actionControl("start_exercise", "Start exercise", compact: true)
                    ExercisePlaybackView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    actionControl("stop_exercise", "Stop exercise", compact: true)
                }
                .padding(.horizontal, 5)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
          } else {
           ScrollView {
            VStack(spacing: 10) {
                if let d = model.device {
                    if let p = d.panel, p.type == "driving" {
                        let rgb = p.color ?? [92, 225, 193]
                        Rectangle().fill(Color(red: Double(rgb[0])/255, green: Double(rgb[1])/255, blue: Double(rgb[2])/255)).frame(height: 5).accessibilityHidden(true)
                    }
                    if let p = d.panel, p.type != "fan" { panel(p) } else { device(d) }
                } else if model.connection != nil {
                    Text("No panel selected").font(.headline)
                } else {
                    Image(systemName: "fan.fill").font(.largeTitle).foregroundStyle(.mint)
                    Text("Fan Control").font(.headline)
                    Text("Connect to Home Assistant").font(.caption)
                    Button("Pair watch") { setup = true }
                }
            }.padding(.horizontal, 5)
        }
          }
        }
        .persistentSystemOverlays(.hidden)
        .onReceive(NotificationCenter.default.publisher(for: .commandOutcomeSaved)) { note in
            if let id = note.object as? String { model.refreshCommandOutcome(id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionSnapshotSaved)) { note in
            model.receiveCompanion(note.object as? CompanionSnapshot)
        }
        .onLongPressGesture { setup = true }
        // Navigation must win over child buttons. A simultaneous drag lets the
        // same touch also activate an HA control and schedule a delayed alert.
        .highPriorityGesture(DragGesture(minimumDistance: 35).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            model.swipe(value.translation.width < 0 ? 1 : -1)
        })
        .onOpenURL { url in
            if url.scheme == "fancontrol", url.host == "active" { model.enter() }
        }
        .sheet(isPresented: $setup, onDismiss: { model.enter(resetSelection: false); entryReady = scenePhase == .active }) { WatchSettingsView(model: model) }
        .onAppear { model.enter(); entryReady = scenePhase == .active }
        .onDisappear { entryReady = false; model.leave() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !setup { model.enter(); entryReady = true }
            else { entryReady = false; model.leave() }
        }
        .onChange(of: setup) { _, value in if value { model.leave() } }
    }
    private func control(_ action: String, _ label: String, known: Bool = true, enabled: Bool = true) -> some View {
        let applies = model.feedback.map { $0.command == action || ToggleIntent.replaces(action, $0.command) } ?? false
        let feedback = applies ? model.feedback : nil
        let gray = feedback?.gray ?? (!model.stateFresh || !known)
        let shown = feedback?.label ?? label
        let blocked = model.busy && !ToggleIntent.replaces(action, model.feedback?.command)
        return Button { model.send(action, label: label) } label: {
            Text(shown).frame(maxWidth: .infinity, minHeight: 40).foregroundStyle(gray ? Color.gray : Color.mint)
        }
        .tint(gray ? Color.gray.opacity(0.25) : Color.mint.opacity(0.18))
        .disabled(blocked || !enabled)
    }
    @ViewBuilder private func device(_ d: Device) -> some View {
        let state = model.observed["state"] as? String
        let available = state == "on" || state == "off"
        if ["script", "scene"].contains(d.domain) {
            actionControl("activate", "Run")
        } else if ["fan", "light", "switch", "input_boolean"].contains(d.domain) {
            // Label projects the absolute next state immediately on the originating control.
            let pending = model.feedback?.phase != .confirmed && (model.feedback?.command == "turn_on" || model.feedback?.command == "turn_off")
            let action = pending ? ToggleIntent.opposite(model.feedback!.command)! : state == "on" ? "turn_off" : "turn_on"
            control(action, pending ? model.feedback!.label : state == "on" ? "ON" : "OFF", known: available)
                
            if d.domain == "fan" {
                let percentage = (model.observed["attributes"] as? [String: Any])?["percentage"] as? Int
                let speed = percentage.flatMap { value in Evidence.percentages.firstIndex(where: { $0 >= value }).map { $0 + 1 } }
                HStack {
                    Button("−") { model.adjust(-1) }.disabled(!model.canAdjustSpeed || model.displayedSpeed <= 1)
                    Text(model.speedDraft.map(String.init) ?? (model.feedback?.command.hasPrefix("speed") == true ? model.feedback!.label : speed.map(String.init) ?? "1"))
                        .foregroundStyle((model.feedback?.command.hasPrefix("speed") == true ? model.feedback!.gray : !model.stateFresh || percentage == nil || model.speedDraft != nil) ? Color.gray : Color.mint)
                    Button("+") { model.adjust(1) }.disabled(!model.canAdjustSpeed || model.displayedSpeed >= 6)
                }
                .tint(.mint)
            }
        } else { Text("Controls unavailable").foregroundStyle(.gray) }
    }
    @ViewBuilder private func panel(_ p: Panel) -> some View {
        if p.type == "on_duty" {
            let departure = FlightPresentation.departure(model.observed["departure"] as? String)
            let fresh = model.stateFresh && model.observed["available"] as? Bool == true
            VStack(spacing: 12) {
                Text(model.observed["city_pair"] as? String ?? "—").font(.title2.bold())
                VStack(spacing: 2) {
                    Text("Departure").font(.caption)
                    if let departure { Text(departure, style: .time).font(.title3) }
                    else { Text("—").font(.title3) }
                }
                VStack(spacing: 2) {
                    Text("Time to go").font(.caption)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(departure.map { FlightPresentation.timeToGo(departure: $0, now: context.date) } ?? "—")
                            .font(.title2.monospacedDigit())
                    }
                }
            }.foregroundStyle(fresh ? Color.mint : Color.gray)
        } else if p.type == "driving" {
            // Five controls fill a two-column, three-row grid; the final cell stays empty.
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                cover("garage", "Garage")
                cover("trunk", "Trunk")
                climate(p)
                actionControl("honk", "Honk Horn")
                Button("Podcast", action: model.openPodcast)
                    .foregroundStyle(.gray).tint(Color.gray.opacity(0.25)).disabled(model.busy)
            }
        } else if p.type == "exercise" {
            actionControl("start_exercise", "Start exercise", compact: true)
            ExercisePlaybackView()
            actionControl("stop_exercise", "Stop exercise", compact: true)
        } else {
            let battery = model.observed["battery"] as? Double
            Text(battery.map { String(format: "%.0f%%", $0) } ?? "?%")
                .foregroundStyle(model.stateFresh && battery != nil ? Color.mint : Color.gray)
            climate(p)
            actionControl("leave", p.script_label ?? "Leave for work")
        }
    }
    @ViewBuilder private func actionControl(_ action: String, _ label: String, compact: Bool = false) -> some View {
        let receipt = model.actionFeedback(action)
        let gray = ActionReceipts.isGray(receipt)
        let button = Button { model.send(action, label: label) } label: {
            Text(receipt == nil ? label : "Activated")
                .frame(maxWidth: .infinity, minHeight: compact ? 36 : 40)
                .foregroundStyle(gray ? Color.gray : Color.mint)
        }
        .tint(gray ? Color.gray.opacity(0.25) : Color.mint.opacity(0.18))
        .disabled(model.busy)
        if compact {
            button.buttonStyle(.plain)
                .background(gray ? Color.gray.opacity(0.12) : Color.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
        } else { button }
    }
    private func climate(_ p: Panel) -> some View {
        let on = model.stateFresh && model.observed["climate_on"] as? Bool == true
        let pending = model.feedback?.phase != .confirmed && model.feedback?.command.hasPrefix("climate_") == true
        let action = CommandPolicy.climateIntent(observedOn: on, fresh: model.stateFresh, previous: pending ? model.feedback?.command : nil)
        let available = model.observed[on && p.type == "driving" ? "climate_off_available" : "climate_available"] as? Bool == true
        return control(action, "\(p.climate_label ?? "Climate")\n\(on ? "ON" : "OFF")", known: available)
    }
    private func cover(_ role: String, _ title: String) -> some View {
        let observed = model.observed[role + "_state"] as? String
        let matching = model.feedback?.command.hasPrefix(role + "_") == true
        let action = matching && model.feedback?.phase != .confirmed ? ToggleIntent.opposite(model.feedback!.command)! : role + "_" + Evidence.coverIntent(observed)
        return control(action, title + "\n" + ToggleIntent.coverPresentation(observed), known: observed == "open" || observed == "closed")
    }
}
