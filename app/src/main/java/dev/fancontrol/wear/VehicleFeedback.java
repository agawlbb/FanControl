package dev.fancontrol.wear;

/** A requested presentation is distinct from both a confirmed state and the HA cache. */
record VehicleFeedback(PanelDefinition panel, String watchId, String action, boolean pending, boolean confirmed) {
    String title() { return CommandFeedback.title(action); }
    boolean appliesTo(String action) {
        return this.action.equals(action) || action.equals("climate") && this.action.startsWith("climate_");
    }
    boolean unconfirmed(String action) { return pending || appliesTo(action) && !confirmed; }
    boolean selected(String action) { return appliesTo(action) && confirmed; }
    String label(String action, String fallback) {
        return appliesTo(action) ? title() + (!pending && !confirmed ? "\nNot confirmed" : "") : fallback;
    }
    boolean matches(PanelDefinition panel, String watchId) { return this.panel.equals(panel) && this.watchId.equals(watchId); }
    String climateState(String observed) {
        return action.equals("climate_on") ? "ON" : action.equals("climate_off") ? "OFF" : observed;
    }
}
