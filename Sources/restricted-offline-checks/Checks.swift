#if DEBUG
// Offline checks execute the real gate against injected mock frames, never a phone.
import Foundation
func XCTFail(_ message: String) { fatalError(message) }
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { if lhs != rhs { fatalError("Expected equal values") } }
func XCTAssertThrowsError<T>(_ body: @autoclosure () throws -> T) {
    do { _ = try body() } catch { return }
    fatalError("Expected rejection")
}
import CoreGraphics
@testable import MirrorCore
@testable import MirrorServer

private actor FakeNavigation {
    var frames: [RestrictedFrame]
    var posts = 0
    init(_ frames: [RestrictedFrame]) { self.frames = frames }
    func read() throws -> RestrictedFrame {
        guard !frames.isEmpty else { throw MirrorError("No mock frame") }
        return frames.removeFirst()
    }
    func post() { posts += 1 }
    func count() -> Int { posts }
}
struct NavigationGateTests {
    func frame(_ text: String, x: CGFloat = 20) -> RestrictedFrame {
        RestrictedFrame(geometry: WindowGeometry(windowID: 1,
            boundsPoints: CGRect(x: 0, y: 0, width: 300, height: 600),
            imagePixelSize: CGSize(width: 600, height: 1200)), elements: [
                OCRElement(text: text, confidence: 0.99, box: CGRect(x: x, y: 300, width: 100, height: 40))
            ])
    }
    func plan(operation: String = "back", expiry: Double = Date().timeIntervalSince1970 + 60) -> NavigationApproval {
        NavigationApproval(windowID: 1, x: 0, y: 0, width: 300, height: 600,
            expiresAt: expiry, steps: [.init(id: "one", operation: operation,
                beforeText: "Before", afterText: "After", targetText: "Before")])
    }
    private func gate(_ plan: NavigationApproval?, _ fake: FakeNavigation) -> NavigationGate {
        NavigationGate(approval: plan, read: { _, _ in try await fake.read() },
                       input: { _, _, _ in await fake.post() })
    }
    func fails(_ gate: NavigationGate, id: String = "one") async {
        do { try await gate.navigate(id: id); XCTFail("must reject") } catch {}
    }
    func testNoApprovalDoesNotReadOrPost() async {
        let fake = FakeNavigation([frame("Before")]); let gate = gate(nil, fake)
        await fails(gate)
        let count = await fake.count(); XCTAssertEqual(count, 0)
        do { _ = try await gate.readScreen(); XCTFail("read must reject") } catch {}
    }
    func testExpiredAndWrongStepDoNotPost() async {
        for p in [plan(expiry: 0), plan()] {
            let fake = FakeNavigation([frame("Before")]); let gate = gate(p, fake)
            await fails(gate, id: "unapproved")
            let count = await fake.count(); XCTAssertEqual(count, 0)
        }
    }
    func testScreenDriftStopsBeforePosting() async {
        let fake = FakeNavigation([frame("Before"), frame("Before", x: 150)])
        let gate = gate(plan(), fake); await fails(gate)
        let count = await fake.count(); XCTAssertEqual(count, 0)
        await fails(gate)
    }
    func testVerifiedStepIsSingleUse() async throws {
        let fake = FakeNavigation([frame("Before"), frame("Before"), frame("After")])
        let gate = gate(plan(), fake)
        try await gate.navigate(id: "one"); await fails(gate)
        let count = await fake.count(); XCTAssertEqual(count, 1)
    }
    func testPostVerificationFailureDoesNotRetryInput() async {
        let fake = FakeNavigation([frame("Before"), frame("Before")])
        let gate = gate(plan(), fake); await fails(gate); await fails(gate)
        let count = await fake.count(); XCTAssertEqual(count, 1)
    }
    func testStopDisarmsAndInvalidPlansReject() async {
        let fake = FakeNavigation([frame("Before")]); let gate = gate(plan(), fake)
        await gate.stop(); await fails(gate)
        let count = await fake.count(); XCTAssertEqual(count, 0)
        XCTAssertThrowsError(try plan(operation: "type_text").validate(now: Date().timeIntervalSince1970))
        XCTAssertThrowsError(try plan(expiry: Date().timeIntervalSince1970 + 1000).validate(now: Date().timeIntervalSince1970))
    }
    func testExtraCoordinatesCannotBeSuppliedThroughMCP() {
        XCTAssertThrowsError(try ToolArgs(["step_id": "one", "x": 100]).only(["step_id"]))
    }
    func testHeaderDuplicateInBodyAndInboxRow() async throws {
        let geometry = frame("Creator").geometry
        let header = OCRElement(text: "Creator", confidence: 0.99, box: CGRect(x: 100,y: 120,width: 120,height: 40))
        let body = OCRElement(text: "Creator", confidence: 0.99, box: CGRect(x: 200,y: 300,width: 120,height: 40))
        let thread = RestrictedFrame(geometry: geometry, elements: [header,body])
        let inbox = RestrictedFrame(geometry: geometry, elements: [body,
            OCRElement(text: "Inbox", confidence: 0.99, box: CGRect(x: 20,y: 200,width: 100,height: 40))])
        let p = NavigationApproval(windowID: 1,x: 0,y: 0,width: 300,height: 600,
            expiresAt: Date().timeIntervalSince1970+60, steps: [
                .init(id: "back",operation: "back",beforeText: "Creator",afterText: "Creator",targetText: nil,beforeRegion: "header",afterRegion: "content"),
                .init(id: "reopen",operation: "tap_text",beforeText: "Creator",afterText: "Creator",targetText: "Creator",beforeRegion: "content",afterRegion: "header",targetRegion: "content")])
        let fake = FakeNavigation([thread,thread,inbox,inbox,inbox,thread])
        let g = gate(p,fake)
        try await g.navigate(id: "back"); try await g.navigate(id: "reopen")
        let count = await fake.count(); XCTAssertEqual(count,2)
        XCTAssertEqual(NavigationGate.matches("Creator",thread,region: "header").count,1)
        XCTAssertEqual(NavigationGate.matches("Creator",inbox,region: "header").count,0)
        let ambiguous = RestrictedFrame(geometry: geometry,elements: [header,header,body])
        let blocked = FakeNavigation([ambiguous]); let blockedGate = gate(p,blocked)
        await fails(blockedGate,id: "back")
        let blockedCount = await blocked.count(); XCTAssertEqual(blockedCount,0)
    }
}

@main
struct OfflineMain {
    static func main() async throws {
        let checks = NavigationGateTests()
        await checks.testNoApprovalDoesNotReadOrPost()
        await checks.testExpiredAndWrongStepDoNotPost()
        await checks.testScreenDriftStopsBeforePosting()
        try await checks.testVerifiedStepIsSingleUse()
        await checks.testPostVerificationFailureDoesNotRetryInput()
        await checks.testStopDisarmsAndInvalidPlansReject()
        checks.testExtraCoordinatesCannotBeSuppliedThroughMCP()
        try await checks.testHeaderDuplicateInBodyAndInboxRow()
        XCTAssertEqual(MirrorWindowBridge.knownChromeButton(role: "AXButton", subrole: nil, identifier: "app.grid.3x3"), true)
        XCTAssertEqual(MirrorWindowBridge.knownChromeButton(role: "AXButton", subrole: nil, identifier: "iphone.app.switcher"), true)
        XCTAssertEqual(MirrorWindowBridge.knownChromeButton(role: "AXButton", subrole: "AXCloseButton", identifier: nil), true)
        XCTAssertEqual(MirrorWindowBridge.knownChromeButton(role: "AXButton", subrole: nil, identifier: "resume"), false)
        XCTAssertEqual(MirrorWindowBridge.knownChromeButton(role: "AXStaticText", subrole: nil, identifier: "app.grid.3x3"), false)
        print("PASS: 8 restricted navigation safety checks; real device input disabled (mock dependencies only).")
        print("PASS: known window chrome accepted; unknown overlay controls remain blocked.")
    }
}

#else
import Foundation
@main
struct OfflineMain {
    static func main() {
        FileHandle.standardError.write(Data("Offline checks require a debug build. Use swift run restricted-offline-checks.\n".utf8))
        exit(2)
    }
}
#endif
