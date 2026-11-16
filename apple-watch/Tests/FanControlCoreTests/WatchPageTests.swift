import XCTest
@testable import FanControlCore
final class WatchPageTests: XCTestCase {
    func testSavedOrderDoesNotMoveActivePanelOrExposeSettings() {
        let order = ["panel.fan", "panel.exercise", "panel.driving"]
        XCTAssertEqual(WatchPage.next(.device(order[1]), entities: order, active: order[1], direction: -1), .device(order[0]))
        XCTAssertEqual(WatchPage.next(.device(order[2]), entities: order, direction: 1), .device(order[2]))
        XCTAssertEqual(WatchPage.next(.device(order[0]), entities: order, direction: -1), .device(order[0]))
    }
    func testRemovedTilesAreDroppedAndNewTilesAppended() {
        let settings = CompanionSettings(order: ["removed", "c", "c", "a"])
        XCTAssertEqual(settings.ordered(["a", "b", "c"]), ["c", "a", "b"])
        XCTAssertEqual(CompanionSettings().ordered(["a", "b"]), ["a", "b"])
        XCTAssertEqual(WatchPage.next(.settings, entities: [], direction: 1), .settings)
    }
}
