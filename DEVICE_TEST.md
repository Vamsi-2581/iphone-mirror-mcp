# Restricted fork device test — 2026-10-11

The operator separately approved a non-private Settings screen, in-memory capture/OCR, one harmless submenu tap, scroll and Back. This test used the compiled restricted fork over stdio, not the CUA input engine. No private Instagram access was performed.

| Check | Result | Evidence |
|---|---|---|
| Existing permissions and selected visible focused Mirroring window | PASS | Read-only metadata; no permission changes or requests. |
| Memory-only ScreenCaptureKit and Vision OCR | PASS on retry | Sanitized output contained only Settings/Battery landmarks, OCR counts, coordinates and confidence. Pixels and full OCR stayed in memory. |
| Paired OCR text/coordinates | PASS for this window | Settings and Battery recognized with confidence 1.0; tapping Battery at the returned target led to the expected page. |
| Approved submenu tap | VERIFIED | Changed content signature plus exact high-confidence Battery postcondition, followed by a separate OCR read. |
| Approved scroll | VERIFIED | Low Power Mode was absent from the initial safe landmark set and present after the scroll, along with changed content. A separate read confirmed it. |
| Approved Back | VERIFIED | Changed content plus exact high-confidence Settings postcondition. |
| Shutdown | PASS | Stop acknowledged, server terminated, temporary private approval file deleted. |
| Initial-capture latency | UNVERIFIED | First read exceeded the 20-second client deadline; server terminated before input. Read-only restart with a 30-second deadline succeeded. No claim about the underlying cause. |
| Immediate in-flight cancellation | UNVERIFIED | Stop does not recall posted CGEvents; no emergency mid-gesture test performed. |
| Resize/movement, changed phone/account, private Instagram, collector integration | UNVERIFIED | Outside this test. |

The three approved navigation steps each used the operator-written plan, two fresh pre-input frames, exact window identity/bounds/focus checks, high-confidence exact OCR conditions, and a verified changed result. No setting/toggle, reply/resource button, external URL, clipboard or message action was used. No screenshot or complete transcript was stored or uploaded. The local collector still uses its manual workflow.

The actual device harness lives in the collector workspace as `settings_fork_probe.py`; it requires an explicit Settings approval flag, sanitizes output, writes only an ephemeral private plan under ignored `.local/`, and terminates/removes it on exit. The source-only fork has no automatic device test workflow.
