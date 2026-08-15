import Foundation
import Observation

enum AppLog {
    static func log(_ message: String) {
        Task { @MainActor in
            DebugLogStore.shared.append(message)
        }
    }

    static func redact(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(
            of: #"serviceKey=[^&]+"#,
            with: "serviceKey=***",
            options: .regularExpression
        )
    }

    static func snippet(_ text: String?, limit: Int = 220) -> String {
        guard let text, !text.isEmpty else { return "(empty)" }
        let compact = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if compact.count <= limit { return compact }
        return String(compact.prefix(limit)) + "…"
    }
}

@MainActor
@Observable
final class DebugLogStore {
    static let shared = DebugLogStore()

    private(set) var lines: [String] = []
    private let maxLines = 300

    private init() {
        append("debug console ready · build 24")
    }

    var joinedText: String {
        lines.joined(separator: "\n")
    }

    func append(_ message: String) {
        let stamp = Self.timestamp()
        lines.append("[\(stamp)] \(message)")
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func clear() {
        lines.removeAll()
        append("cleared")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
