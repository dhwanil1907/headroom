import Foundation
import Testing

@testable import HeadroomCore

@Suite struct ProviderTests {
  @Test func claudeParsesWindows() throws {
    let json = #"{"five_hour":{"utilization":23,"resets_at":"2026-10-20T17:20:00.000Z"},"seven_day":{"utilization":61,"resets_at":"2026-10-24T09:30:00Z"}}"#
    guard case .ok(let headline, let metrics) = ClaudeProvider.parse(Data(json.utf8)) else {
      Issue.record("expected ok")
      return
    }
    #expect(headline == 61)
    #expect(metrics.map(\.label) == ["5-hour", "Weekly"])
    #expect(metrics[0].resetsAt != nil)
  }

  @Test func claudeEmptyPayloadFails() {
    #expect(
      ClaudeProvider.parse(Data("{}".utf8))
        == .failed(.malformedResponse("response had no usage windows")))
  }

  @Test func cursorParsesPlan() {
    let json = #"{"billingCycleEnd":"2026-10-31T23:49:00.000Z","individualUsage":{"plan":{"autoPercentUsed":56,"apiPercentUsed":57,"totalPercentUsed":57}}}"#
    guard case .ok(let headline, let metrics) = CursorProvider.parse(Data(json.utf8)) else {
      Issue.record("expected ok")
      return
    }
    #expect(headline == 57)
    #expect(metrics.map(\.percentUsed) == [56, 57])
  }

  @Test func cursorUnlimitedAndNoLimit() {
    #expect(CursorProvider.parse(Data(#"{"isUnlimited":true}"#.utf8)) == .unlimited)
    #expect(CursorProvider.parse(Data("{}".utf8)) == .noLimit)
  }

  @Test func missingCredentialsNeedsSignIn() async {
    let provider = ClaudeProvider(credentials: StaticCredentials([:]))
    #expect(await provider.fetch() == .failed(.needsCredentials))
  }
}

@Suite struct TokenTests {
  @Test func compactFormatting() {
    #expect(TokenFormat.compact(950) == "950")
    #expect(TokenFormat.compact(1_234_567) == "1.2346M")
    #expect(TokenFormat.compact(2_500_000_000) == "2.5000B")
  }

  @Test func claudeCodeUsesStatsCacheThenLogs() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let stats = dir.appendingPathComponent("stats-cache.json")
    let missing = dir.appendingPathComponent("none.json")
    let log = #"{"message":{"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":100}}}"#
    try (log + "\n" + log).write(to: dir.appendingPathComponent("a.jsonl"), atomically: true, encoding: .utf8)
    #expect(ClaudeCodeTokens.lifetimeTotal(statsFile: missing, logRoot: dir) == 230)

    let cache = #"{"modelUsage":{"a":{"inputTokens":1,"outputTokens":2,"cacheReadInputTokens":3,"cacheCreationInputTokens":4},"b":{"outputTokens":10}}}"#
    try cache.write(to: stats, atomically: true, encoding: .utf8)
    // Stale cache (20) is below the live logs (230), so the logs win.
    #expect(ClaudeCodeTokens.lifetimeTotal(statsFile: stats, logRoot: dir) == 230)

    // Cache remembers history whose logs were deleted, so the larger cache wins.
    let bigCache = #"{"modelUsage":{"a":{"outputTokens":1000}}}"#
    try bigCache.write(to: stats, atomically: true, encoding: .utf8)
    #expect(ClaudeCodeTokens.lifetimeTotal(statsFile: stats, logRoot: dir) == 1000)
  }
}

@Suite struct InsightTests {
  @Test func levelThresholds() {
    #expect(UsageLevel(percent: 74.9) == .normal)
    #expect(UsageLevel(percent: 75) == .warning)
    #expect(UsageLevel(percent: 90) == .critical)
  }

  @Test func compactDurations() {
    #expect(Durations.compact(30) == "<1m")
    #expect(Durations.compact(12 * 60) == "12m")
    #expect(Durations.compact(3 * 3600 + 12 * 60) == "3h 12m")
    #expect(Durations.compact(4 * 86400 + 2 * 3600) == "4d 2h")
  }

  @Test func timeToLimitOnlyWhenHitBeforeReset() {
    let now = Date()
    let window: TimeInterval = 5 * 3600
    // 2h elapsed, 50% used -> 1%/2.4min, 100% in 2h; 3h remain -> will hit the limit.
    let hit = TimeToLimit.estimate(
      percentUsed: 50, windowSeconds: window, resetsAt: now.addingTimeInterval(3 * 3600), now: now)
    #expect(hit != nil && abs(hit! - 2 * 3600) < 1)
    // 2h elapsed, 10% used -> would need 18h; resets first.
    #expect(
      TimeToLimit.estimate(
        percentUsed: 10, windowSeconds: window, resetsAt: now.addingTimeInterval(3 * 3600), now: now)
        == nil)
    // Too early in the window to trust the rate.
    #expect(
      TimeToLimit.estimate(
        percentUsed: 5, windowSeconds: window, resetsAt: now.addingTimeInterval(window - 60), now: now)
        == nil)
    #expect(TimeToLimit.estimate(percentUsed: 50, windowSeconds: nil, resetsAt: now, now: now) == nil)
  }
}
