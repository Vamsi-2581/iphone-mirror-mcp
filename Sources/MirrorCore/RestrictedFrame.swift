import CoreGraphics
import Foundation

/// Image and OCR are paired from one in-memory capture. Pixels never leave this API.
public struct RestrictedFrame: Sendable {
    public let geometry: WindowGeometry
    public let elements: [OCRElement]
    public init(geometry: WindowGeometry, elements: [OCRElement]) {
        self.geometry = geometry
        self.elements = elements
    }
}

extension MirrorSession {
    private func approvedWindow(_ windowID: UInt32, bounds: CGRect) throws -> MirrorWindowInfo {
        if let error = ensureReady(forInput: true) { throw error }
        guard let info = bridge.windowInfo(), info.windowID == windowID,
              info.bounds == bounds, bridge.findProcess()?.isActive == true else {
            throw MirrorError("Selected window, geometry, or focus changed; blocked.")
        }
        return info
    }

    public func restrictedFrame(windowID: UInt32, bounds: CGRect) async throws -> RestrictedFrame {
        let info = try approvedWindow(windowID, bounds: bounds)
        let capture = try await MirrorCapture.capture(windowInfo: info)
        let elements = try MirrorOCR.recognizeText(in: capture.image)
        _ = try approvedWindow(windowID, bounds: bounds)
        return RestrictedFrame(geometry: capture.geometry, elements: elements)
    }

    /// No remapping into changed bounds and no activation or retry of input.
    public func restrictedInput(geometry: WindowGeometry, from: CGPoint, to: CGPoint?) throws {
        _ = try approvedWindow(geometry.windowID, bounds: geometry.boundsPoints)
        let size = geometry.imagePixelSize
        let points = [from] + (to.map { [$0] } ?? [])
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.x >= 0.02 * size.width
            && $0.x <= 0.98 * size.width && $0.y >= 0.08 * size.height
            && $0.y <= 0.90 * size.height }) else {
            throw MirrorError("Approved point is outside the navigation area.")
        }
        let start = try geometry.screenPoint(fromPixelX: Double(from.x), pixelY: Double(from.y))
        let center = CGPoint(x: geometry.boundsPoints.midX, y: geometry.boundsPoints.midY)
        if let to {
            let end = try geometry.screenPoint(fromPixelX: Double(to.x), pixelY: Double(to.y))
            try MirrorInput.swipe(from: start, to: end, durationMs: 600,
                                  through: center, windowBounds: geometry.boundsPoints)
        } else {
            try MirrorInput.tap(at: start, through: center, windowBounds: geometry.boundsPoints)
        }
    }
}
