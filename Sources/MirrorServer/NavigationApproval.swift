import CoreGraphics
import Darwin
import Foundation
import MirrorCore

/// Only the trusted local operator writes this file; MCP has no approval tool.
struct NavigationApproval: Codable, Sendable {
    struct Step: Codable, Sendable {
        let id: String
        let operation: String // tap_text, back, scroll_up, scroll_down
        let beforeText: String
        let afterText: String
        let targetText: String?
    }
    let windowID: UInt32
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let expiresAt: Double // Unix seconds; at most 15 minutes from startup
    let steps: [Step]
    var bounds: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    func validate(now: Double) throws {
        guard windowID != 0, [x, y, width, height, expiresAt].allSatisfy(\.isFinite),
              width >= 150, height >= 300, width <= 2000, height <= 3000,
              expiresAt > now, expiresAt <= now + 900,
              !steps.isEmpty, steps.count <= 8, Set(steps.map(\.id)).count == steps.count else {
            throw MirrorError("Invalid or expired local navigation approval.")
        }
        for step in steps {
            guard !step.id.isEmpty, step.id.count <= 64,
                  ["tap_text", "back", "scroll_up", "scroll_down"].contains(step.operation),
                  !step.beforeText.isEmpty, !step.afterText.isEmpty,
                  step.beforeText.count <= 200, step.afterText.count <= 200,
                  step.operation != "tap_text" || !(step.targetText ?? "").isEmpty else {
                throw MirrorError("Invalid approved navigation step.")
            }
        }
    }

    static func load() throws -> NavigationApproval? {
        guard let path = ProcessInfo.processInfo.environment["MIRROR_APPROVAL_FILE"] else { return nil }
        let url = URL(fileURLWithPath: path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        guard path.hasPrefix("/"), attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              let mode = attrs[.posixPermissions] as? NSNumber, mode.intValue & 0o077 == 0,
              ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) <= 16384,
              url.resolvingSymlinksInPath().path == url.standardizedFileURL.path else {
            throw MirrorError("Approval must be an owned, private regular file without symlinks.")
        }
        let plan = try JSONDecoder().decode(NavigationApproval.self, from: Data(contentsOf: url))
        try plan.validate(now: Date().timeIntervalSince1970)
        return plan
    }
}

/// Dependencies are injectable so safety behavior can be tested without a phone.
actor NavigationGate {
    typealias Reader = @Sendable (UInt32, CGRect) async throws -> RestrictedFrame
    typealias Input = @Sendable (WindowGeometry, CGPoint, CGPoint?) async throws -> Void
    let approval: NavigationApproval?
    let read: Reader
    let input: Input
    var next = 0
    var stopped = false
    var busy = false
    var reads = 0
    private var epoch = 0

    init(approval: NavigationApproval?, read: @escaping Reader, input: @escaping Input) {
        self.approval = approval
        self.read = read
        self.input = input
    }
    func stop() { stopped = true; epoch += 1 }
    func status() -> String {
        "Approved plan: \(approval == nil ? "absent" : "present"); stopped: \(stopped); next step: \(next); read calls: \(reads)/20"
    }
    private func current() throws -> NavigationApproval {
        guard !stopped, let approval, Date().timeIntervalSince1970 < approval.expiresAt else {
            throw MirrorError("Navigation is unapproved, stopped, or expired. Local restart required.")
        }
        return approval
    }
    private func capture(_ plan: NavigationApproval) async throws -> RestrictedFrame {
        _ = try current()
        let frame = try await read(plan.windowID, plan.bounds)
        _ = try current()
        guard frame.geometry.windowID == plan.windowID, frame.geometry.boundsPoints == plan.bounds else {
            throw MirrorError("Selected window geometry changed.")
        }
        return frame
    }
    static func matches(_ text: String, _ frame: RestrictedFrame) -> [OCRElement] {
        frame.elements.filter { $0.text == text && $0.confidence >= 0.9 }
    }
    static func signature(_ frame: RestrictedFrame) -> [String] {
        // Exclude status bar clock and toolbar; retain text and approximate position.
        frame.elements.filter { $0.center.y > frame.geometry.imagePixelSize.height * 0.14 }
            .map { "\($0.text)|\(Int($0.center.x / 8))|\(Int($0.center.y / 8))" }.sorted()
    }
    func readScreen() async throws -> [OCRElement] {
        guard !busy else { throw MirrorError("Navigation busy.") }
        do {
            let plan = try current()
            guard reads < 20 else { throw MirrorError("Read limit reached.") }
            reads += 1
            busy = true
            defer { busy = false }
            return try await capture(plan).elements
        } catch {
            stop()
            throw MirrorError("Approved screen read failed; stopped.")
        }
    }
    func navigate(id: String) async throws {
        guard !busy else { throw MirrorError("Navigation busy.") }
        busy = true
        defer { busy = false }
        do {
            let plan = try current()
            guard next < plan.steps.count, plan.steps[next].id == id else {
                throw MirrorError("Unapproved or out-of-order step.")
            }
            let step = plan.steps[next]
            let generation = epoch
            let first = try await capture(plan)
            guard Self.matches(step.beforeText, first).count == 1 else {
                throw MirrorError("Screen precondition absent or ambiguous.")
            }
            let fresh = try await capture(plan)
            guard generation == epoch, fresh.geometry == first.geometry,
                  Self.signature(first) == Self.signature(fresh),
                  Self.matches(step.beforeText, fresh).count == 1 else {
                throw MirrorError("Screen changed before navigation.")
            }
            let size = fresh.geometry.imagePixelSize
            let from: CGPoint
            var to: CGPoint? = nil
            switch step.operation {
            case "tap_text":
                let candidates = Self.matches(step.targetText ?? "", fresh)
                guard candidates.count == 1 else { throw MirrorError("Target absent or ambiguous.") }
                from = candidates[0].center
            case "back":
                // Fixed, locally approved top-left Back control; no arbitrary coordinates.
                from = CGPoint(x: size.width * 0.08, y: size.height * 0.12)
            case "scroll_down":
                from = CGPoint(x: size.width * 0.55, y: size.height * 0.70)
                to = CGPoint(x: size.width * 0.55, y: size.height * 0.40)
            case "scroll_up":
                from = CGPoint(x: size.width * 0.55, y: size.height * 0.40)
                to = CGPoint(x: size.width * 0.55, y: size.height * 0.70)
            default: throw MirrorError("Unsupported navigation operation.")
            }
            _ = try current()
            guard generation == epoch else { throw MirrorError("Stopped before input.") }
            // Consume before dispatch. A failed gesture is never automatically retried.
            next += 1
            try await input(fresh.geometry, from, to)
            let deadline = Date().addingTimeInterval(8)
            while Date() < deadline {
                let after = try await capture(plan)
                guard generation == epoch, after.geometry == fresh.geometry else {
                    throw MirrorError("Stopped or geometry changed during verification.")
                }
                if Self.signature(after) != Self.signature(fresh), Self.matches(step.afterText, after).count == 1 {
                    if next == plan.steps.count { stop() }
                    return
                }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            throw MirrorError("Navigation effect unverified.")
        } catch {
            stop()
            throw MirrorError("Navigation blocked or unverified; plan stopped. Inspect manually.")
        }
    }
}
