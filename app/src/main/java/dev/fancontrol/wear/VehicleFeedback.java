package dev.fancontrol.wear;

/** A requested presentation is distinct from both a confirmed state and the HA cache. */
record VehicleFeedback(PanelDefinition panel, String watchId, String action, boolean pending, boolean confirmed) {
    String title() { return CommandFeedback.title(action); }
    String label(String action, String fallback) { return this.action.equals(action) ? title() : fallback; }
    boolean matches(PanelDefinition panel, String watchId) { return this.panel.equals(panel) && this.watchId.equals(watchId); }
    String climateState(String observed) {
        if (!(pending || confirmed)) return observed;
        return action.equals("climate_on") ? "ON" : action.equals("climate_off") ? "OFF" : observed;
    }
}
