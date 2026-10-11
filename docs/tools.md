# Restricted MCP tools

| Tool | Arguments | Scope |
|---|---|---|
| `status` | none | Session/window ID and existing permission flags; no capture or input. |
| `read_screen` | none | OCR of the approved focused visible window; up to 20 calls. |
| `navigate` | `step_id` | Next operator-approved step only; screen verification required. |
| `stop` | none | Disarm plan; no automatic rearm. |

Additional arguments and unlisted tools are rejected. See the root README for the local approval format. This tool catalog is deliberately separate from the historical upstream catalog.
