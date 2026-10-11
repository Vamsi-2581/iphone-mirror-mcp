# Restricted iPhone Mirroring feasibility fork

A restricted fork of [nickatnight96/iphone-mirror-mcp](https://github.com/nickatnight96/iphone-mirror-mcp), based on commit `5a676528ec7779ec49927f7469c7aebc0806125c`. MIT license and upstream copyright are preserved. Upstream gesture-engine attribution is retained in source comments.

**Experimental source: debug build, targeted offline checks and a narrow Settings device test pass.** A local collector now connects over stdio; its approved Instagram OCR and one conversation scroll passed. Back/reopen coverage remains incomplete. This is not a general inbox collector.

## Changes

- No permission requests. Missing Screen Recording or Accessibility fails closed.
- No automatic resume, focus activation, AppleScript fallback, or hidden-window capture.
- ScreenCaptureKit captures the exact visible window in memory. No disk fallback; recording APIs throw.
- MCP exposes exactly `status`, `read_screen`, `navigate`, and `stop`. Unknown tools are rejected at dispatch. Raw tap/swipe, typing, clipboard, URLs, notifications, Xcode and simulator tools are inaccessible through MCP.
- Input and OCR reads require a trusted operator's private local approval file. Without it, only status and stop work. There is no MCP tool to create, alter, or rearm approval.
- Approved steps run once, in order, within 15 minutes, with at most eight steps and 20 separate read calls. Navigation checks two fresh OCR frames, exact window bounds, focus, confidence and preconditions, then verifies changed screen content and a postcondition. Failures disarm the plan without retrying input.
- Optional operator-only beforeRegion/afterRegion/targetRegion values distinguish `header` (8–16% of captured height) from `content` (over 16%, through 90%). Unknown regions are rejected. Exact text and confidence >=0.9 remain required within the selected region; duplicate matches there still stop. These regions require validating the approved portrait layout.
- `read_screen` includes paired window ID and image size followed by OCR lines. Confidence preserves full precision. Approved labels augment Vision's local custom vocabulary; they do not lower confidence requirements. Known Mirroring toolbar/window controls are distinguished from pause overlays; unknown accessibility children still block.
- The upstream installer refuses to install this fork automatically. Upstream package/registry manifests and release workflows are removed to avoid installing an unrestricted upstream binary by mistake.

## Approval and use

Build and local execution need explicit operator approval. After approval, use `scripts/run_tests.sh` from this directory for the debug build, mock safety checks, static restrictions and real stdio checks. The full upstream XCTest suite requires Xcode with XCTest; `scripts/run_tests.sh --full` attempts it. The currently installed Command Line Tools cannot compile XCTest. Do not enable `MIRROR_MCP_LIVE`; legacy live tests can drive a real phone. A future device test must use a harmless Settings screen first.

After successful build/tests, a trusted local operator prepares a file outside the repository with mode `0600`. Never commit a real approval file: it may contain private text and window information. The file must be owned by the launching user, cannot be a symlink, and cannot exceed 16 KiB. `expiresAt` is a Unix timestamp no more than 15 minutes after startup. `windowID`, x/y/width/height must identify the current visible Mirroring window. All labels are exact OCR strings.

```json
{
  "windowID": 123,
  "x": 100, "y": 100, "width": 300, "height": 650,
  "expiresAt": 0,
  "steps": [
    {"id": "battery", "operation": "tap_text", "beforeText": "Settings", "targetText": "Battery", "afterText": "Battery"},
    {"id": "back", "operation": "back", "beforeText": "Battery", "afterText": "Settings"}
  ]
}
```

The example is deliberately expired and uses fictitious geometry; it grants no access. The operator must approve navigation-only targets. Other operations are `scroll_down` and `scroll_up`, with before/after landmarks that verify the intended scroll. `back` uses a fixed top-left point (8% width, 12% height) and must be verified visually for the approved screen before use. No arbitrary coordinates may be supplied through MCP.

Open, resume, and focus iPhone Mirroring manually. A trusted local client launches the reviewed binary with `MIRROR_APPROVAL_FILE=/absolute/private/path.json`. It calls `navigate` with only `{"step_id":"battery"}` and then the next approved ID. New actions require a new operator-approved plan and server restart. Stop or expiry prevents further reads and input.

## Validation status

On 2026-10-11, the debug fork compiled on Apple Silicon with all seven dependencies pinned by Package.resolved. Eight safety checks exercise the actual NavigationGate with mock dependencies, including region disambiguation, and real stdio checks verify initialization, the four-tool catalog and 21 tool calls without approval. Static and known-chrome checks pass. The parent collector passes 60 Python tests and synthetic GUI integration checks. Full upstream XCTest cannot compile with the installed Command Line Tools and is not reported as passing.

A separately approved Settings test verified memory-only capture/OCR, paired coordinates, Battery tap, scroll and Back. The subsequent collector connection verified approved Instagram OCR and one scroll; Back/reopen live coverage is incomplete. Capture deadlines and genuine pause/focus loss interrupted some runs. General inbox scanning, arbitrary layouts/devices, movement/resize coverage and immediate in-flight cancellation remain unverified. See [DEVICE_TEST.md](DEVICE_TEST.md) for evidence and [SECURITY.md](SECURITY.md) for the trust boundary.
