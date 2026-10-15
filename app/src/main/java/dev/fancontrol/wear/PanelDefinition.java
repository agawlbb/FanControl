package dev.fancontrol.wear;

import org.json.JSONObject;

/** Panel layout and entity choices come exclusively from encrypted HA configuration. */
record PanelDefinition(String id, String name, String batteryEntity, String climateEntity,
                       String scriptEntity, String climateLabel, String scriptLabel, String wakeEntity, String awakeEntity, String type, String lockEntity) {
    PanelDefinition(String id, String name, String batteryEntity, String climateEntity, String scriptEntity, String climateLabel, String scriptLabel, String wakeEntity, String awakeEntity) {
        this(id, name, batteryEntity, climateEntity, scriptEntity, climateLabel, scriptLabel, wakeEntity, awakeEntity, "work_morning", "");
    }
    PanelDefinition(String id, String name, String batteryEntity, String climateEntity, String scriptEntity, String climateLabel, String scriptLabel) {
        this(id, name, batteryEntity, climateEntity, scriptEntity, climateLabel, scriptLabel, "", "");
    }
    boolean exercise() { return type.equals("exercise"); }
    boolean vehicle() { return !wakeEntity.isEmpty(); }
    PanelDefinition {
        if (!java.util.List.of("work_morning", "exercise").contains(type)) throw new IllegalArgumentException("Unsupported panel");
        if (type.equals("exercise") && (!lockEntity.matches("lock[.][a-z0-9_]+") || lockEntity.length() > 160
                || !climateEntity.matches("climate[.][a-z0-9_]+") || wakeEntity.isEmpty())) throw new IllegalArgumentException("Invalid Exercise roles");
        if ((!wakeEntity.isEmpty() || !awakeEntity.isEmpty()) &&
                (!wakeEntity.matches("button[.][a-z0-9_]+") || !awakeEntity.matches("binary_sensor[.][a-z0-9_]+")
                || wakeEntity.length() > 160 || awakeEntity.length() > 160)) throw new IllegalArgumentException("Invalid vehicle entities");
        if (!id.matches("[a-z][a-z0-9_]{0,39}") || id.equals("devices")) throw new IllegalArgumentException("Invalid panel ID");
        if (!type.equals("exercise") && (!batteryEntity.matches("sensor[.][a-z0-9_]+") || !climateEntity.matches("(climate|switch|input_boolean)[.][a-z0-9_]+")
                || !scriptEntity.matches("script[.][a-z0-9_]+"))) throw new IllegalArgumentException("Invalid panel entity");
        for (String entity : java.util.List.of(batteryEntity, climateEntity, scriptEntity))
            if (entity.length() > 160) throw new IllegalArgumentException("Invalid panel entity");
        if (name.isBlank() || name.length() > 40 || climateLabel.isBlank() || climateLabel.length() > 12
                || scriptLabel.isBlank() || scriptLabel.length() > 18) throw new IllegalArgumentException("Invalid panel labels");
    }
    static PanelDefinition fromJson(JSONObject json) throws Exception {
        if (json.getString("type").equals("exercise")) return new PanelDefinition(json.getString("id"), json.getString("name"), "", json.getString("climate_entity"), "", "Start", "Stop", json.getString("wake_entity"), json.getString("awake_entity"), "exercise", json.getString("lock_entity"));
        if (!json.getString("type").equals("work_morning")) throw new IllegalArgumentException("Unsupported panel");
        return new PanelDefinition(json.getString("id"), json.getString("name"), json.getString("battery_entity"),
                json.getString("climate_entity"), json.getString("script_entity"), json.getString("climate_label"), json.getString("script_label"), json.optString("wake_entity", ""), json.optString("awake_entity", ""));
    }
    JSONObject toJson() throws Exception {
        if (exercise()) return new JSONObject().put("type", type).put("id", id).put("name", name).put("lock_entity", lockEntity)
                .put("climate_entity", climateEntity).put("wake_entity", wakeEntity).put("awake_entity", awakeEntity);
        return new JSONObject().put("type", "work_morning").put("id", id).put("name", name).put("battery_entity", batteryEntity)
                .put("climate_entity", climateEntity).put("script_entity", scriptEntity).put("climate_label", climateLabel).put("script_label", scriptLabel).put("wake_entity", wakeEntity).put("awake_entity", awakeEntity);
    }
    @Override public String toString() { return "PanelDefinition[redacted]"; }
}
