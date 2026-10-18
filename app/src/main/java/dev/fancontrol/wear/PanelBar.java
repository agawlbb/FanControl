package dev.fancontrol.wear;

import androidx.wear.protolayout.ColorBuilders;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.protolayout.ModifiersBuilders;
import static androidx.wear.protolayout.DimensionBuilders.dp;

/** Identification stripe only; panel selection belongs to Home Assistant. */
final class PanelBar {
    static LayoutElementBuilders.Box tile(String packageName,PanelDefinition panel) {
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(160)).setHeight(dp(20))
                .setModifiers(new ModifiersBuilders.Modifiers.Builder()
                        .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription("Car identification color").build()).build())
                .addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(160)).setHeight(dp(8))
                        .setModifiers(new ModifiersBuilders.Modifiers.Builder().setBackground(new ModifiersBuilders.Background.Builder()
                                .setColor(ColorBuilders.argb(PanelColor.display(panel)))
                                .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(4)).build()).build()).build()).build()).build();
    }
    private PanelBar() { }
}
