package dev.fancontrol.wear;

/** Ambiguous configurations never silently choose a garage or vehicle. */
final class DrivingPanels {
    static PanelDefinition unique(ConnectionSettings settings) {
        if(settings==null||!settings.integration()) return null;
        PanelDefinition preferred=settings.devices().get(0).panel();
        if(preferred!=null&&preferred.driving()) return preferred;
        java.util.List<PanelDefinition> panels=settings.devices().stream().map(DeviceDefinition::panel)
                .filter(panel->panel!=null&&panel.driving()).collect(java.util.stream.Collectors.toList());
        return panels.size()==1?panels.get(0):null;
    }
    private DrivingPanels() { }
}
