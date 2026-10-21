import Foundation

public struct CursorProvider: UsageProvider {
  public let id = "cursor"
  public let displayName = "Cursor"
  public let credentialFields = [
    CredentialField(
      key: "sessionToken", label: "Session cookie",
      placeholder: "cursor.com cookie 'WorkosCursorSessionToken'")
  ]
  public let login: LoginSpec? = LoginSpec(
    url: URL(string: "https://cursor.com/dashboard")!, cookieDomain: "cursor.com",
    cookieName: "WorkosCursorSessionToken")

  private let credentials: CredentialSource
  private let fetcher: Fetcher

  public init(credentials: CredentialSource, fetcher: Fetcher = URLSessionFetcher()) {
    self.credentials = credentials
    self.fetcher = fetcher
  }

  struct Plan: Decodable {
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let totalPercentUsed: Double?
  }

  struct Individual: Decodable { let plan: Plan? }

  struct Summary: Decodable {
    let billingCycleEnd: String?
    let isUnlimited: Bool?
    let individualUsage: Individual?
  }

  public func fetch() async -> ProviderStatus {
    guard let token = credentials.value(provider: id, key: "sessionToken"), !token.isEmpty else {
      return .failed(.needsCredentials)
    }
    do {
      let result = try await fetcher.get(
        URL(string: "https://cursor.com/api/usage-summary")!, cookie: "WorkosCursorSessionToken=\(token)")
      if result.statusCode == 401 || result.statusCode == 403 { return .failed(.needsCredentials) }
      guard result.statusCode == 200 else { return .failed(.unexpectedStatus(result.statusCode)) }
      return Self.parse(result.data)
    } catch {
      return .failed(.malformedResponse(String(describing: error)))
    }
  }

  static func parse(_ data: Data) -> ProviderStatus {
    guard let summary = try? JSONDecoder().decode(Summary.self, from: data) else {
      return .failed(.malformedResponse("unreadable usage payload"))
    }
    if summary.isUnlimited == true { return .unlimited }
    guard let plan = summary.individualUsage?.plan, let total = plan.totalPercentUsed else { return .noLimit }
    let resets = Timestamps.parse(summary.billingCycleEnd)
    let metrics = [
      UsageMetric(label: "Cursor Models", percentUsed: plan.autoPercentUsed ?? 0, resetsAt: resets),
      UsageMetric(label: "Other Models", percentUsed: plan.apiPercentUsed ?? 0, resetsAt: resets),
    ]
    return .ok(headline: total, metrics: metrics)
  }
}
