import Foundation
import MCP
import MirrorCore

enum RestrictedMirroringTools {
    static func all(session: MirrorSession, approval: NavigationApproval? = nil) -> [RegisteredTool] {
        let gate = NavigationGate(approval: approval,
            read: { id, bounds in try await session.restrictedFrame(windowID: id, bounds: bounds) },
            input: { geometry, from, to in try await session.restrictedInput(geometry: geometry, from: from, to: to) })
        let empty: Value = .object(["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)])
        return [
            RegisteredTool(name: "status", description: "Read permission/session flags without capture, launch, resume, or input.", schema: empty) { args in
                try args.only([])
                let state = await session.status()
                return textResult("Session: \(state.state)\nWindow ID: \(state.windowID.map(String.init) ?? "none")\n\(state.permissions.description)\n\(await gate.status())")
            },
            RegisteredTool(name: "read_screen", description: "Read OCR only for the locally approved, visible, focused window. Requires private approval file; limited to 20 calls.", schema: empty) { args in
                try args.only([])
                return textResult(describeElements(try await gate.readScreen()))
            },
            RegisteredTool(name: "navigate", description: "Execute the next step ID in the operator's local approval file. Coordinates and labels cannot be provided through MCP. Stops on failed verification.", schema: .object([
                "type": .string("object"), "properties": .object(["step_id": .object(["type": .string("string"), "description": .string("ID of the next locally approved navigation step.")])]),
                "required": .array([.string("step_id")]), "additionalProperties": .bool(false)
            ])) { args in
                try args.only(["step_id"])
                try await gate.navigate(id: args.string("step_id"))
                return textResult("Approved navigation verified.")
            },
            RegisteredTool(name: "stop", description: "Disarm the current plan. No automatic rearm or resume.", schema: empty) { args in
                try args.only([])
                await gate.stop()
                return textResult("Plan stopped.")
            }
        ]
    }
}
