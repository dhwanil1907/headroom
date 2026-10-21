import Foundation

public enum UsageLevel: Equatable {
  case normal, warning, critical

  public static let warningThreshold = 75.0
  public static let criticalThreshold = 90.0

  public init(percent: Double) {
    if percent >= Self.criticalThreshold {
      self = .critical
    } else if percent >= Self.warningThreshold {
      self = .warning
    } else {
      self = .normal
    }
  }
}

public enum Durations {
  /// "3h 12m", "4d 2h", "12m"; anything under a minute is "<1m".
  public static func compact(_ seconds: TimeInterval) -> String {
    let total = Int(max(seconds, 0))
    let days = total / 86400
    let hours = (total % 86400) / 3600
    let minutes = (total % 3600) / 60
    if days > 0 { return "\(days)d \(hours)h" }
    if hours > 0 { return "\(hours)h \(minutes)m" }
    if minutes > 0 { return "\(minutes)m" }
    return "<1m"
  }
}

public enum TimeToLimit {
  /// Minimum share of the window that must have elapsed before the burn rate is trusted.
  static let minimumElapsedFraction = 0.05

  /// Seconds until 100% at the current burn rate, or nil when the limit won't be reached before
  /// the window resets (or there isn't enough data to say).
  public static func estimate(
    percentUsed: Double, windowSeconds: TimeInterval?, resetsAt: Date?, now: Date = Date()
  ) -> TimeInterval? {
    guard let windowSeconds, let resetsAt, percentUsed > 0, percentUsed < 100 else { return nil }
    let untilReset = resetsAt.timeIntervalSince(now)
    let elapsed = windowSeconds - untilReset
    guard untilReset > 0, elapsed >= windowSeconds * minimumElapsedFraction else { return nil }
    let secondsToFull = (100 - percentUsed) / (percentUsed / elapsed)
    return secondsToFull < untilReset ? secondsToFull : nil
  }
}
