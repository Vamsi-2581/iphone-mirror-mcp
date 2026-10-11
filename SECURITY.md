# Restricted fork security boundary

This fork restricts the MCP interface; it is **not an OS sandbox**. macOS Accessibility and Screen Recording permissions remain broad for the launching application. Upstream library helpers remain in source for compatibility and tests; an arbitrary program linking MirrorCore, or a client with shell/file access, can bypass this MCP policy. Only connect a trusted local client whose scope you control.

## Explicit local approval

Only status/permission flags are readable by default. An owned private file supplied at process startup enables a selected window and a short, ordered navigation plan. The model cannot create approval through MCP or send new coordinates, labels, actions, or URLs. The operator must personally approve navigation-only targets and the private screen access. OCR and planned labels are not proof of an app's identity, user intent, or the semantic safety of a button. A malicious local client with write access can change approval files or restart the process; this mechanism does not protect against that client.

Exact window identity, geometry, positive focus, OCR confidence, before/after landmarks and a changed content signature guard each action. These checks reduce misclick risk but cannot eliminate a screen changing between observation and input. A selected window identifies the Mirroring window, not a particular paired phone or Instagram account. Hardware testing is still required.

## Pixels and text

ScreenCaptureKit and Vision operate in memory. The disk screenshot fallback is removed, and recording APIs throw. MCP does not expose a screenshot or video tool. `read_screen` returns approved-window OCR to the client; the client's own logs or configured model may store or transmit it. Use the local collector with cloud inference disabled. This server does not control client storage, swap, crash dumps or OS capture behavior; memory-only is not a guarantee against those mechanisms. Approval files can contain private labels; keep them outside source control with mode 0600.

No permission requests, automatic resume, activation or AppleScript execution occur in the restricted paths. A paused session or failed verification requires manual inspection and a new approved plan. Startup reads an approval file once; modifying/deleting that file does not revoke a running plan. Use `stop` or terminate the process to revoke it.

## Stopping

The `stop` tool bypasses the FIFO queue and permanently disarms the current plan. It blocks subsequent captures/input after the next gate check. It cannot recall a CGEvent already posted or reliably interrupt a synchronous in-flight gesture (scroll is limited to 600 ms, with additional pointer engagement time). Unlock/pick up the physical iPhone to pause Mirroring, or terminate the server. Immediate device-level cancellation is unverified; do not claim it is implemented.

## Deployment

This is unvalidated experimental source. Do not use upstream installers, bundles or releases for this fork. The fork installer intentionally fails rather than install. Local build/runtime require operator approval; begin with offline tests and an explicitly approved harmless Settings screen. No private Instagram session is authorized merely by building or connecting this server. Inbox-wide scanning, message/reply buttons, external links, community joins, and message sending are outside this prototype's scope.

Retain the MIT license and upstream credits. Report fork-specific issues privately to the repository owner; do not publish private OCR, screenshots or approval files in an issue.
