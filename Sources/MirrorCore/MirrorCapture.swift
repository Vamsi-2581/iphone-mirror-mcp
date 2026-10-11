import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// A captured frame of the mirroring window plus the geometry needed to map
/// screenshot pixels back to screen points.
public struct CaptureResult: Sendable {
    public let image: CGImage
    public let geometry: WindowGeometry
}

/// Captures the iPhone Mirroring window.
///
/// Primary path is ScreenCaptureKit's screenshot API with a
/// desktop-independent window filter — unlike `screencapture -l` it works
/// even when the window is occluded or on another macOS Space, so capture
/// never needs to steal focus. This fork has no disk capture fallback.
public enum MirrorCapture {
    public static func capture(windowInfo: MirrorWindowInfo) async throws -> CaptureResult {
        guard CGPreflightScreenCaptureAccess() else {
            throw MirrorError.screenRecordingDenied()
        }
        guard windowInfo.windowID != 0 else { throw MirrorError.windowNotFound() }
        // Memory only. A failed capture is an error, never a disk fallback.
        return try await captureWithSCK(windowInfo: windowInfo)
    }

    static func captureWithSCK(windowInfo: MirrorWindowInfo) async throws -> CaptureResult {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let scWindow = content.windows.first {
            $0.windowID == windowInfo.windowID
                && $0.owningApplication?.bundleIdentifier == MirrorWindowBridge.bundleID
                && $0.frame == windowInfo.bounds
        }
        guard let scWindow else {
            throw MirrorError("ScreenCaptureKit could not find the iPhone Mirroring window (id \(windowInfo.windowID)).")
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(scWindow.frame.width * scale))
        configuration.height = max(1, Int(scWindow.frame.height * scale))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration)
        let geometry = WindowGeometry(
            windowID: windowInfo.windowID,
            boundsPoints: windowInfo.bounds,
            imagePixelSize: CGSize(width: image.width, height: image.height)
        )
        return CaptureResult(image: image, geometry: geometry)
    }

    // Preserve source compatibility while disabling all recording paths.
    public static func startRecordingProcess(
        windowInfo: MirrorWindowInfo, outputPath: String?
    ) throws -> (process: Process, path: String) {
        throw MirrorError("Recording is disabled in this restricted fork.")
    }

    public static func record(
        windowInfo: MirrorWindowInfo, seconds: Int, outputPath: String?
    ) async throws -> String {
        throw MirrorError("Recording is disabled in this restricted fork.")
    }

    /// A capture failure with the permission GRANTED is almost always a
    /// transient window-server condition (window mid-transition, Space
    /// switch, session pause) — blaming the permission sends the caller to
    /// System Settings for nothing. Only blame it when it is actually missing.
    static func captureRemediation(permissionGranted: Bool) -> String {
        if permissionGranted {
            return "Screen Recording is granted, so this is usually transient (window mid-transition, Space switch, or the session pausing). Retry; if it persists, check the session with the status tool."
        }
        return "Check Screen Recording permission for the app hosting this MCP server."
    }
}
