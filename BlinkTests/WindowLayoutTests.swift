import XCTest
import AppKit
@testable import Blink

/// Tests for the pure overlay window-layout decision.
///
/// This is the #54-class seam: layout is computed from explicit screen frames
/// instead of a live `NSScreen.screens` read, so multi-monitor and
/// connect/disconnect-mid-break scenarios are reproducible without any windows.
final class WindowLayoutTests: XCTestCase {

    typealias Controller = BreakOverlayWindowController
    typealias Decision = BreakOverlayWindowController.WindowLayoutDecision

    private let screenA = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let screenB = CGRect(x: 1440, y: 0, width: 2560, height: 1440)

    private func layout(screens: [CGRect],
                        primaryVisible: CGRect? = nil,
                        phase: BreakPhase,
                        style: BreakStyle,
                        visible: Bool = true) -> Decision {
        Controller.calculateWindowLayout(
            screenFrames: screens,
            primaryVisibleFrame: primaryVisible ?? screens.first,
            phase: phase,
            breakStyle: style,
            isOverlayVisible: visible
        )
    }

    // MARK: - Visibility

    func testHiddenOverlayProducesEmptyLayout() {
        let d = layout(screens: [screenA, screenB], phase: .fullscreen, style: .enforced, visible: false)
        XCTAssertTrue(d.isEmpty)
        XCTAssertFalse(d.usesFullscreen)
    }

    // MARK: - Enforced

    func testEnforcedProducesOneFullscreenPerScreen() {
        let d = layout(screens: [screenA, screenB], phase: .fullscreen, style: .enforced)
        XCTAssertEqual(d.fullscreenFrames, [screenA, screenB])
        XCTAssertTrue(d.dimFrames.isEmpty)
        XCTAssertNil(d.floatingFrame)
    }

    func testEnforcedFloatingPhaseStillFullscreen() {
        // Enforced ignores phase — always full cover.
        let d = layout(screens: [screenA], phase: .floating, style: .enforced)
        XCTAssertTrue(d.usesFullscreen)
        XCTAssertEqual(d.fullscreenFrames, [screenA])
    }

    // MARK: - Gentle

    func testGentleFloatingProducesDimPlusFloating() {
        let d = layout(screens: [screenA, screenB], primaryVisible: screenA, phase: .floating, style: .gentle)
        XCTAssertFalse(d.usesFullscreen)
        XCTAssertEqual(d.dimFrames, [screenA, screenB])
        XCTAssertEqual(d.dimOpacity, Controller.LayoutConstants.floatingDimOpacity)
        XCTAssertEqual(d.floatingFrame?.size, Controller.LayoutConstants.floatingSize)
    }

    func testGentleDimmedIsDarkerAndLarger() {
        let d = layout(screens: [screenA], phase: .dimmed, style: .gentle)
        XCTAssertEqual(d.dimOpacity, Controller.LayoutConstants.dimmedDimOpacity)
        XCTAssertEqual(d.floatingFrame?.size, Controller.LayoutConstants.dimmedFloatingSize)
    }

    /// Guard the constants' relationship directly (so equal/inverted opacity
    /// or non-growing floating size can't slip past the per-phase tests above,
    /// which compare against the same constants the production reads).
    func testDimmedPhaseIsDarkerAndLargerThanFloating() {
        XCTAssertGreaterThan(Controller.LayoutConstants.dimmedDimOpacity,
                             Controller.LayoutConstants.floatingDimOpacity)
        XCTAssertGreaterThan(Controller.LayoutConstants.dimmedFloatingSize.width,
                             Controller.LayoutConstants.floatingSize.width)
    }

    func testGentleFullscreenPhaseEscalatesToFullscreen() {
        let d = layout(screens: [screenA, screenB], phase: .fullscreen, style: .gentle)
        XCTAssertTrue(d.usesFullscreen)
        XCTAssertEqual(d.fullscreenFrames, [screenA, screenB])
        XCTAssertNil(d.floatingFrame)
    }

    func testGentleWithNoPrimaryVisibleFrameStillDimsButNoFloating() {
        let d = Controller.calculateWindowLayout(
            screenFrames: [screenA], primaryVisibleFrame: nil,
            phase: .floating, breakStyle: .gentle, isOverlayVisible: true)
        XCTAssertEqual(d.dimFrames, [screenA])
        XCTAssertNil(d.floatingFrame, "No primary visible frame → no floating popup")
    }

    // MARK: - #54: monitor connect/disconnect mid-break

    func testEnforcedMonitorDisconnectDropsToRemainingScreen() {
        let before = layout(screens: [screenA, screenB], phase: .fullscreen, style: .enforced)
        XCTAssertEqual(before.fullscreenFrames.count, 2)

        // External display unplugged — recompute with the remaining screen only.
        let after = layout(screens: [screenA], phase: .fullscreen, style: .enforced)
        XCTAssertEqual(after.fullscreenFrames, [screenA],
                       "Disconnect should leave exactly one fullscreen cover on the remaining display")
    }

    func testGentleMonitorDisconnectKeepsCurrentPhase() {
        // Re-showing after a display change must preserve the CURRENT phase
        // (dimmed), not collapse back to floating — the #54 regression.
        let after = layout(screens: [screenA], phase: .dimmed, style: .gentle)
        XCTAssertEqual(after.dimFrames, [screenA])
        XCTAssertEqual(after.dimOpacity, Controller.LayoutConstants.dimmedDimOpacity)
    }

    func testNoScreensProducesEmptyButValidLayout() {
        let d = layout(screens: [], phase: .fullscreen, style: .enforced)
        XCTAssertTrue(d.fullscreenFrames.isEmpty)
        XCTAssertTrue(d.isEmpty)
    }

    // MARK: - Floating frame math

    func testFloatingFramePositionedBottomRightWithInset() {
        let frame = Controller.floatingFrame(
            in: CGRect(x: 0, y: 0, width: 1440, height: 900),
            size: CGSize(width: 400, height: 300))
        XCTAssertEqual(frame.origin.x, 1440 - 400 - 20)
        XCTAssertEqual(frame.origin.y, 20)
        XCTAssertEqual(frame.size, CGSize(width: 400, height: 300))
    }

    func testFloatingFrameRespectsNonZeroVisibleOrigin() {
        // visibleFrame excludes menu bar / Dock, so origin is rarely (0,0).
        let frame = Controller.floatingFrame(
            in: CGRect(x: 100, y: 50, width: 1300, height: 800),
            size: CGSize(width: 400, height: 300))
        XCTAssertEqual(frame.origin.x, (100 + 1300) - 400 - 20)
        XCTAssertEqual(frame.origin.y, 50 + 20)
    }
}
