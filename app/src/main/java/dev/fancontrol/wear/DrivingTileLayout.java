package dev.fancontrol.wear;

import androidx.wear.protolayout.ColorBuilders;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.protolayout.ModifiersBuilders;
import static androidx.wear.protolayout.DimensionBuilders.dp;
import static androidx.wear.protolayout.DimensionBuilders.sp;

/** Shared by the dedicated Driving tile and the active-panel main tile. Rendering performs no I/O. */
final class DrivingTileLayout {
    static LayoutElementBuilders.Column content(String packageName,PanelDefinition panel,String watchId,
                                                DeviceController.Snapshot state,VehicleFeedback feedback) {
        LayoutElementBuilders.Column.Builder column=new LayoutElementBuilders.Column.Builder()
                .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER);
        column.addContent(PanelBar.tile(packageName,panel));
        java.util.List<DrivingState.Control> controls=DrivingState.controls(state,feedback,panel!=null);
        LayoutElementBuilders.Row.Builder top=new LayoutElementBuilders.Row.Builder();
        top.addContent(button(packageName,panel,watchId,controls.get(0),78,72));
        top.addContent(new LayoutElementBuilders.Spacer.Builder().setWidth(dp(4)).build());
        top.addContent(button(packageName,panel,watchId,controls.get(2),78,72));
        column.addContent(top.build());
        column.addContent(new LayoutElementBuilders.Spacer.Builder().setHeight(dp(4)).build());
        column.addContent(button(packageName,panel,watchId,controls.get(1),160,44));
        if(panel==null) column.addContent(new LayoutElementBuilders.Text.Builder().setText("Configure Driving in HA")
                .setFontStyle(new LayoutElementBuilders.FontStyle.Builder().setSize(sp(11)).setColor(ColorBuilders.argb(CommandFeedback.GRAY)).build()).build());
        return column.build();
    }
    private static LayoutElementBuilders.Box button(String packageName,PanelDefinition panel,String watchId,DrivingState.Control control,int width,int height) {
            ModifiersBuilders.Modifiers.Builder modifiers=new ModifiersBuilders.Modifiers.Builder()
                    .setBackground(new ModifiersBuilders.Background.Builder()
                            .setColor(ColorBuilders.argb(CommandFeedback.background(control.unconfirmed()||!control.enabled(),control.selected())))
                            .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(12)).build()).build())
                    .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(control.label()).build());
            if(control.enabled()) modifiers.setClickable(ExerciseTileService.action(packageName,panel,control.action(),watchId));
            return new LayoutElementBuilders.Box.Builder().setWidth(dp(width)).setHeight(dp(height)).setModifiers(modifiers.build())
                    .addContent(new LayoutElementBuilders.Text.Builder().setText(control.label()).setMaxLines(3)
                            .setFontStyle(new LayoutElementBuilders.FontStyle.Builder().setSize(sp(14))
                                    .setColor(ColorBuilders.argb(CommandFeedback.foreground(control.unconfirmed()||!control.enabled(),control.selected()))).build()).build()).build();
    }
    private DrivingTileLayout() { }
}
