import Foundation

public struct UsageMetric: Identifiable, Equatable {
  public let label: String
  public let percentUsed: Double
  public let resetsAt: Date?
  /// Length of the usage window, when known; enables the time-to-limit estimate.
  public let windowSeconds: TimeInterval?
  public var id: String { label }

  public init(label: String, percentUsed: Double, resetsAt: Date?, windowSeconds: TimeInterval? = nil) {
    self.label = label
    self.percentUsed = percentUsed
    self.resetsAt = resetsAt
    self.windowSeconds = windowSeconds
  }
}

public enum ProviderError: Error, Equatable {
  case needsCredentials
  case unexpectedStatus(Int)
  case malformedResponse(String)
}

public enum ProviderStatus: Equatable {
  case ok(headline: Double, metrics: [UsageMetric])
  case unlimited
  case noLimit
  case failed(ProviderError)
}

public struct CredentialField: Equatable {
  public let key: String
  public let label: String
  public let placeholder: String

  public init(key: String, label: String, placeholder: String = "") {
    self.key = key
    self.label = label
    self.placeholder = placeholder
  }
}

public struct LoginSpec: Equatable {
  public let url: URL
  public let cookieDomain: String
  public let cookieName: String

  public init(url: URL, cookieDomain: String, cookieName: String) {
    self.url = url
    self.cookieDomain = cookieDomain
    self.cookieName = cookieName
  }
}

public protocol UsageProvider {
  var id: String { get }
  var displayName: String { get }
  var credentialFields: [CredentialField] { get }
  var login: LoginSpec? { get }
  func fetch() async -> ProviderStatus
  /// Total tokens used over the account's lifetime, or nil when unavailable.
  func lifetimeTokens() async -> Int?
}

extension UsageProvider {
  public func lifetimeTokens() async -> Int? { nil }
}

public enum TokenFormat {
  /// Compact display, e.g. 1_234_567 -> "1.2346M".
  public static func compact(_ count: Int) -> String {
    let units: [(Double, String)] = [(1e9, "B"), (1e6, "M"), (1e3, "K")]
    let value = Double(count)
    for (size, suffix) in units where value >= size {
      return String(format: "%.4f%@", value / size, suffix)
    }
    return String(count)
  }
}

public enum Timestamps {
  private static let withFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  private static let plain = ISO8601DateFormatter()

  public static func parse(_ text: String?) -> Date? {
    guard let text else { return nil }
    return withFraction.date(from: text) ?? plain.date(from: text)
  }
}
