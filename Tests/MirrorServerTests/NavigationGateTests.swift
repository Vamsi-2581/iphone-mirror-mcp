import CoreGraphics
import XCTest
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
final class NavigationGateTests: XCTestCase {
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
}
