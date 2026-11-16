import SwiftUI
import WidgetKit

struct PanelEntry: TimelineEntry { let date: Date }
struct PanelProvider: TimelineProvider {
    func placeholder(in context: Context) -> PanelEntry { PanelEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PanelEntry) -> Void) { completion(PanelEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PanelEntry>) -> Void) {
        completion(Timeline(entries: [PanelEntry(date: .now)], policy: .never))
    }
}

struct PanelComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Label("Open active panel", systemImage: "switch.2")
            } else {
                Image(systemName: "switch.2").accessibilityLabel("Open active panel")
            }
        }
        .widgetURL(URL(string: "fancontrol://active"))
        .containerBackground(.clear, for: .widget)
    }
}

@main struct ActivePanelComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ActivePanel", provider: PanelProvider()) { _ in PanelComplicationView() }
            .configurationDisplayName("Active Panel")
            .description("Open the panel selected in Home Assistant.")
            .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}
