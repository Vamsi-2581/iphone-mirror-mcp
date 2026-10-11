# Restricted iPhone Mirroring feasibility fork

A restricted fork of [nickatnight96/iphone-mirror-mcp](https://github.com/nickatnight96/iphone-mirror-mcp), based on commit `5a676528ec7779ec49927f7469c7aebc0806125c`. MIT license and upstream copyright are preserved. Upstream gesture-engine attribution is retained in source comments.

**Experimental source, not yet build-tested or device-validated. Do not treat this as an Instagram inbox collector.** The local collector still uses its existing manual workflow. This fork is a separate, unconnected backend candidate.

## Changes

- No permission requests. Missing Screen Recording or Accessibility fails closed.
- No automatic resume, focus activation, AppleScript fallback, or hidden-window capture.
- ScreenCaptureKit captures the exact visible window in memory. No disk fallback; recording APIs throw.
- MCP exposes exactly `status`, `read_screen`, `navigate`, and `stop`. Unknown tools are rejected at dispatch. Raw tap/swipe, typing, clipboard, URLs, notifications, Xcode and simulator tools are inaccessible through MCP.
- Input and OCR reads require a trusted operator's private local approval file. Without it, only status and stop work. There is no MCP tool to create, alter, or rearm approval.
- Approved steps run once, in order, within 15 minutes, with at most eight steps and 20 separate read calls. Navigation checks two fresh OCR frames, exact window bounds, focus, confidence and preconditions, then verifies changed screen content and a postcondition. Failures disarm the plan without retrying input.
- The upstream installer refuses to install this fork automatically. Upstream package/registry manifests and release workflows are removed to avoid installing an unrestricted upstream binary by mistake.

## Approval and use

Build and local execution need explicit operator approval. After approval, use `swift build` and `swift test` from this directory. Do not enable `MIRROR_MCP_LIVE`; legacy live tests can drive a real phone. A future device test must use a harmless Settings screen first.

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

Swift syntax parsing and static restriction checks have passed. Regression tests for the parent Python collector passed (52 tests). New Swift safety/protocol tests are committed, but compilation, Swift tests, MCP runtime transport, ScreenCaptureKit capture, coordinate mapping, scroll behavior, and actual device cancellation remain unverified until an approved build and Settings-only test. See [SECURITY.md](SECURITY.md) before connecting a client.
