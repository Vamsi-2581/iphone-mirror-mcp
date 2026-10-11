import Foundation
import MirrorCore

/// The binary's command-line surface.
///
/// The default (no arguments) is the stdio MCP server, because that is how
/// every MCP client launches it. The other subcommands exist for the human
/// setting that up: an MCP server started by hand looks identical to a hung
/// process — it waits silently on stdin for a JSON-RPC frame that never
/// comes — so without `--version` and `doctor` there is no way to confirm the
/// binary works before wiring it into a client and hoping.
public enum CLI {
    public enum Command: Equatable {
        case serve
        case doctor
        case version
        case help
        /// An argument the parser does not recognize.
        case unknown(String)
    }

    /// Exit codes. `doctor` distinguishes "ran fine, setup is broken" (1)
    /// from "you typed something wrong" (2) so scripts can tell them apart.
    public enum ExitCode {
        public static let ok: Int32 = 0
        public static let checksFailed: Int32 = 1
        public static let usage: Int32 = 2
    }

    /// Parses arguments *excluding* the executable path.
    public static func parse(_ arguments: [String]) -> Command {
        guard let first = arguments.first else { return .serve }
        switch first {
        case "serve", "--serve":
            return .serve
        case "doctor", "--doctor":
            return .doctor
        case "--version", "-v", "version":
            return .version
        case "--help", "-h", "help":
            return .help
        default:
            return .unknown(first)
        }
    }

    public static var versionLine: String {
        "\(MirrorMCPServer.name) \(MirrorMCPServer.version)"
    }

    public static var helpText: String {
        """
        \(versionLine)
        Restricted iPhone Mirroring navigation feasibility server.
        Usage: iphone-mirror-mcp [serve | doctor | --version | --help]
        doctor reads permission/session flags only; it does not test input or capture.
        Set MIRROR_APPROVAL_FILE to a private, operator-written approval plan before serve.
        Without a plan, only status and stop work. See README.md and SECURITY.md.
        Open, focus and resume Mirroring manually. This server requests no permissions.
        """
    }

    /// Runs the command and returns the process exit code. `serve` only
    /// returns when the client disconnects.
    public static func run(_ arguments: [String]) async throws -> Int32 {
        switch parse(arguments) {
        case .serve:
            try await MirrorMCPServer.run()
            return ExitCode.ok

        case .version:
            print(versionLine)
            return ExitCode.ok

        case .help:
            print(helpText)
            return ExitCode.ok

        case .doctor:
            let report = await MirrorSession().status()
            print("Session: \(report.state)\n\(report.permissions.description)")
            return report.permissions.accessibility && report.permissions.screenRecording
                ? ExitCode.ok : ExitCode.checksFailed

        case .unknown(let argument):
            FileHandle.standardError.write(Data("Unknown argument \"\(argument)\".\n\n".utf8))
            FileHandle.standardError.write(Data((helpText + "\n").utf8))
            return ExitCode.usage
        }
    }
}
