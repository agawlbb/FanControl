package dev.fancontrol.wear;

/** Device names and entity IDs are stored only inside encrypted connection settings. */
public record DeviceDefinition(String entityId, String title, PanelDefinition panel) {
    public DeviceDefinition(String entityId, String title) { this(entityId, title, null); }
    public DeviceDefinition {
        if (panel != null && !entityId.equals("panel." + panel.id())) throw new IllegalArgumentException("Panel ID mismatch");
        if (entityId == null || !entityId.matches("[a-z_][a-z0-9_]*\\.[a-z0-9_]+") || entityId.length() > 160)
            throw new IllegalArgumentException("Invalid device entity ID");
        if (title == null || title.isBlank() || title.length() > 80)
            throw new IllegalArgumentException("Invalid device title");
    }
    public String domain() { return entityId.substring(0, entityId.indexOf('.')); }
    @Override public String toString() { return "DeviceDefinition[redacted]"; }
}
