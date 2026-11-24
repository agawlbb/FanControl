import XCTest
@testable import FanControlCore

final class FlightPageSelectionTests: XCTestCase {
    func testOpensOnExistingFocusAndEachSwipeMovesOneWholeFlight() {
        var pages = FlightPageSelection()
        pages.update(keys: ["previous", "current", "next", "last"], openingIndex: 1)
        XCTAssertEqual(pages.index, 1)
        guard case .flight(let up) = FlightTileSwipe.direction(x: 2, y: -200) else {
            return XCTFail("Upward swipe should select the following flight")
        }
        pages.step(up)
        XCTAssertEqual(pages.index, 2)
        guard case .flight(let down) = FlightTileSwipe.direction(x: 1, y: 40) else {
            return XCTFail("Downward swipe should select the previous flight")
        }
        pages.step(down)
        XCTAssertEqual(pages.index, 1)
        pages.step(-1); pages.step(-1)
        XCTAssertEqual(pages.index, 0)
        pages.step(1); pages.step(1); pages.step(1); pages.step(1)
        XCTAssertEqual(pages.index, 3)
        XCTAssertEqual(FlightTileSwipe.direction(x: 100, y: -20), .tile(-1))
        XCTAssertEqual(FlightTileSwipe.direction(x: 30, y: -30), .flight(1))
        XCTAssertNil(FlightTileSwipe.direction(x: 0, y: -5))
        XCTAssertEqual(TileSwipe.direction(x: -100, y: 20), 1)
    }

    func testDiagonalSwipesAlwaysChooseOneAxisAndCancelledDragsDoNotTap() {
        // These diagonals previously fell between both 1.5x direction thresholds.
        XCTAssertEqual(FlightTileSwipe.direction(x: -40, y: -35), .tile(1))
        XCTAssertEqual(FlightTileSwipe.direction(x: 35, y: -40), .flight(1))
        XCTAssertEqual(FlightTileSwipe.direction(x: 35, y: 40), .flight(-1))
        XCTAssertEqual(FlightTileSwipe.direction(x: 40, y: 35), .tile(-1))
        XCTAssertEqual(FlightTileSwipe.direction(x: 9, y: -9), .flight(1))
        // The native exclusive drag branch ignores these; only TapGesture opens crew.
        XCTAssertNil(FlightTileSwipe.direction(x: 0, y: 0))
        XCTAssertNil(FlightTileSwipe.direction(x: 3, y: -3))
        XCTAssertNil(FlightTileSwipe.direction(x: .nan, y: 30))
    }

    func testCrownUsesBoundedDiscreteFlightPositions() {
        var pages = FlightPageSelection()
        pages.update(keys: ["a", "b", "c"], openingIndex: 1)
        pages.crown(2)
        XCTAssertEqual(pages.index, 2)
        pages.crown(1)
        XCTAssertEqual(pages.index, 1)
        pages.crown(0)
        XCTAssertEqual(pages.index, 0)
        pages.crown(-100)
        XCTAssertEqual(pages.index, 0)
        pages.crown(100)
        XCTAssertEqual(pages.index, 2)
        pages.crown(.nan)
        XCTAssertEqual(pages.index, 2)
    }

    func testUpdatesRetainManualPageAndDoNotFollowChangedOpeningFocus() {
        var pages = FlightPageSelection()
        pages.update(keys: [], openingIndex: nil)
        XCTAssertNil(pages.index)
        pages.step(1); pages.crown(1)
        XCTAssertNil(pages.index)
        pages.update(keys: ["a", "b", "c"], openingIndex: 2)
        XCTAssertEqual(pages.index, 2)
        pages.step(-1)
        pages.update(keys: ["a", "b", "c"], openingIndex: 2)
        XCTAssertEqual(pages.index, 1)
        pages.update(keys: ["b", "c"], openingIndex: 1)
        XCTAssertEqual(pages.index, 0)
        pages.update(keys: ["new-trip"], openingIndex: 10)
        XCTAssertEqual(pages.index, 0)
        pages.update(keys: [], openingIndex: 0)
        XCTAssertNil(pages.index)
    }

    func testAirportLabelsUseIATAForCachedMixedICAOAndInternationalCodes() {
        XCTAssertEqual(FlightPresentation.airportPair("KCLT → KBOS"), "CLT → BOS")
        XCTAssertEqual(FlightPresentation.airportPair(" bos → KCLT "), "BOS → CLT")
        XCTAssertEqual(FlightPresentation.airportPair("CYVR → KDFW"), "YVR → DFW")
        XCTAssertEqual(FlightPresentation.airportPair("MMUN → MWCR"), "CUN → GCM")
        XCTAssertEqual(FlightPresentation.airportPair("MKJS → MYNN"), "MBJ → NAS")
        XCTAssertEqual(FlightPresentation.airportPair("MDPC → MDSD"), "PUJ → SDQ")
        XCTAssertEqual(FlightPresentation.airportPair("MUCM → TIST"), "CMW → STT")
        XCTAssertEqual(FlightPresentation.airportPair("ZZZZ → KCLT"), "— → CLT")
        XCTAssertEqual(FlightPresentation.airportPair(nil), "—")
        XCTAssertEqual(FlightPresentation.airportPair("Boston"), "—")
    }
}
