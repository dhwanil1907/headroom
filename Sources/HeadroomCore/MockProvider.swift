import Foundation

public struct MockProvider: UsageProvider {
  public let id: String
  public let displayName: String
  public let credentialFields: [CredentialField] = []
  public let login: LoginSpec? = nil
  private let result: ProviderStatus

  public init(id: String, displayName: String, result: ProviderStatus) {
    self.id = id
    self.displayName = displayName
    self.result = result
  }

  public func fetch() async -> ProviderStatus { result }

  public static func sampleRegistry() -> [UsageProvider] {
    let reset = Date().addingTimeInterval(3 * 3600)
    return [
      MockProvider(
        id: "claude", displayName: "Claude",
        result: .ok(headline: 61, metrics: [
          UsageMetric(label: "5-hour", percentUsed: 23, resetsAt: reset),
          UsageMetric(label: "Weekly", percentUsed: 61, resetsAt: reset.addingTimeInterval(86400 * 4)),
        ])),
      MockProvider(
        id: "cursor", displayName: "Cursor",
        result: .ok(headline: 57, metrics: [
          UsageMetric(label: "Cursor Models", percentUsed: 56, resetsAt: reset.addingTimeInterval(86400 * 10)),
          UsageMetric(label: "Other Models", percentUsed: 57, resetsAt: reset.addingTimeInterval(86400 * 10)),
        ])),
    ]
  }
}
