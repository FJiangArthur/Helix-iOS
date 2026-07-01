import Foundation

public enum EvalStatus: String, Codable, Sendable {
    case pass = "PASS"
    case fail = "FAIL"
}

public struct LatencySummary: Codable, Equatable, Sendable {
    public var p50Ms: Int
    public var p95Ms: Int
    public var maxMs: Int

    public init(latenciesMs: [Int]) {
        let sorted = latenciesMs.sorted()
        self.p50Ms = Self.percentile(sorted, 0.50)
        self.p95Ms = Self.percentile(sorted, 0.95)
        self.maxMs = sorted.last ?? 0
    }

    private static func percentile(_ sorted: [Int], _ percentile: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * percentile).rounded())))
        return sorted[index]
    }
}

public struct EvalCheck: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var area: String
    public var status: EvalStatus
    public var latencyMs: Int
    public var expected: String
    public var actual: String
    public var details: String
    public var reportOnly: Bool
    public var latencyReportOnly: Bool

    public init(
        id: String,
        area: String,
        status: EvalStatus,
        latencyMs: Int,
        expected: String,
        actual: String,
        details: String = "",
        reportOnly: Bool = false,
        latencyReportOnly: Bool = false
    ) {
        self.id = id
        self.area = area
        self.status = status
        self.latencyMs = latencyMs
        self.expected = expected
        self.actual = actual
        self.details = details
        self.reportOnly = reportOnly
        self.latencyReportOnly = latencyReportOnly
    }
}

public struct EvalReport: Codable, Equatable, Sendable {
    public var overall: EvalStatus
    public var startedAt: Date
    public var gitSha: String
    public var simulatorUdid: String
    public var latencySummary: LatencySummary
    public var checks: [EvalCheck]

    public init(startedAt: Date = Date(), gitSha: String, simulatorUdid: String, checks: [EvalCheck]) {
        let requiredFailures = checks.filter { !$0.reportOnly && $0.status == .fail }
        self.overall = requiredFailures.isEmpty ? .pass : .fail
        self.startedAt = startedAt
        self.gitSha = gitSha
        self.simulatorUdid = simulatorUdid
        self.latencySummary = LatencySummary(latenciesMs: checks.map(\.latencyMs))
        self.checks = checks
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public func markdownSummary() -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "# Helix Conversation Eval Report",
            "",
            "- Overall: \(overall.rawValue)",
            "- Started: \(formatter.string(from: startedAt))",
            "- Git SHA: \(gitSha)",
            "- Simulator: \(simulatorUdid)",
            "- Latency p50/p95/max: \(latencySummary.p50Ms)/\(latencySummary.p95Ms)/\(latencySummary.maxMs) ms",
            "",
            "| ID | Area | Status | Latency | Expected | Actual | Details |",
            "| --- | --- | --- | ---: | --- | --- | --- |"
        ]

        for check in checks {
            lines.append(
                "| \(check.id.markdownTableEscaped) | \(check.area.markdownTableEscaped) | \(check.status.rawValue) | \(check.latencyMs) ms | \(check.expected.markdownTableEscaped) | \(check.actual.markdownTableEscaped) | \(check.details.markdownTableEscaped) |"
            )
        }

        return lines.joined(separator: "\n") + "\n"
    }
}

public struct EvalReportArtifact: Equatable, Sendable {
    public var jsonURL: URL
    public var markdownURL: URL

    public init(jsonURL: URL, markdownURL: URL) {
        self.jsonURL = jsonURL
        self.markdownURL = markdownURL
    }
}

public struct EvalReportWriter: Sendable {
    public init() {}

    public func write(
        _ report: EvalReport,
        to directory: URL,
        basename: String = "helix_eval_report"
    ) throws -> EvalReportArtifact {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let jsonURL = directory.appendingPathComponent("\(basename).json")
        let markdownURL = directory.appendingPathComponent("\(basename).md")

        try report.encodedJSON().write(to: jsonURL, options: [.atomic])
        try Data(report.markdownSummary().utf8).write(to: markdownURL, options: [.atomic])

        return EvalReportArtifact(jsonURL: jsonURL, markdownURL: markdownURL)
    }
}

private extension String {
    var markdownTableEscaped: String {
        replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "\r", with: "")
    }
}
