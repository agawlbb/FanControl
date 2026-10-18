package dev.fancontrol.wear;

import org.json.JSONArray;
import org.json.JSONObject;

/** Optional RGB metadata; the default is visual only and never changes old command grants. */
final class PanelColor {
    static int read(JSONObject json) throws Exception {
        if(!json.has("color")) return 0;
        JSONArray color=json.getJSONArray("color");
        if(color.length()!=3) throw new IllegalArgumentException("Invalid panel color");
        int value=0xFF000000;
        for(int index=0;index<3;index++) {
            Object part=color.get(index);
            if(!(part instanceof Number number)||number.doubleValue()!=number.intValue()||number.intValue()<0||number.intValue()>255)
                throw new IllegalArgumentException("Invalid panel color");
            value|=((Number)part).intValue() << (16-index*8);
        }
        return value;
    }
    static JSONObject write(JSONObject json,int color) throws Exception {
        if(color!=0) json.put("color",new JSONArray().put((color>>16)&255).put((color>>8)&255).put(color&255));
        return json;
    }
    static int display(PanelDefinition panel) { return panel==null||panel.barColor()==0?CommandFeedback.CONFIRMED:panel.barColor(); }
    private PanelColor() { }
}
