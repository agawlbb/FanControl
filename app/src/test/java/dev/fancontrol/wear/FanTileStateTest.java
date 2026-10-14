package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;

public class FanTileStateTest {
    @Test public void newSessionIsUnknownUntilAvailableResult() {
        FanTileState state = new FanTileState();
        assertNull(state.current());
        DeviceController.Snapshot on = DeviceControllers.Fan.snapshot(new FanState(true, 3, true, true));
        state.confirm(on);
        assertSame(on, state.current());
    }
    @Test public void leavingOrFailedFetchDiscardsPreviouslyConfirmedState() {
        FanTileState state = new FanTileState();
        state.confirm(DeviceControllers.Fan.snapshot(new FanState(true, 6, true, true)));
        state.clear();
        assertNull(state.current());
        state.confirm(DeviceControllers.Fan.snapshot(new FanState(false, 0, true, true)));
        assertNotNull(state.current());
        state.clear();
        assertNull(state.current());
    }
    @Test public void unavailableResultCannotRevivePreviousState() {
        FanTileState state = new FanTileState();
        state.confirm(DeviceControllers.Fan.snapshot(new FanState(true, 3, true, true)));
        state.confirm(DeviceControllers.Fan.snapshot(new FanState(false, 0, false, false)));
        assertNull(state.current());
    }
}
