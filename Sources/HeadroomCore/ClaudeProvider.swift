import Foundation

public struct ClaudeProvider: UsageProvider {
  public let id = "claude"
  public let displayName = "Claude"
  public let credentialFields = [
    CredentialField(
      key: "sessionKey", label: "Session cookie",
      placeholder: "claude.ai cookie 'sessionKey', starts with sk-ant-sid01-")
  ]
  public let login: LoginSpec? = LoginSpec(
    url: URL(string: "https://claude.ai/login")!, cookieDomain: "claude.ai", cookieName: "sessionKey")

  private let credentials: CredentialSource
  private let fetcher: Fetcher

  public init(credentials: CredentialSource, fetcher: Fetcher = URLSessionFetcher()) {
    self.credentials = credentials
    self.fetcher = fetcher
  }

  struct Window: Decodable {
    let utilization: Double?
    let resets_at: String?
  }

  struct UsageResponse: Decodable {
    let five_hour: Window?
    let seven_day: Window?
  }

  struct Organization: Decodable { let uuid: String }

  public func fetch() async -> ProviderStatus {
    guard let session = credentials.value(provider: id, key: "sessionKey"), !session.isEmpty else {
      return .failed(.needsCredentials)
    }
    let cookie = "sessionKey=\(session)"
    do {
      let orgs = try await fetcher.get(URL(string: "https://claude.ai/api/organizations")!, cookie: cookie)
      if orgs.statusCode == 401 || orgs.statusCode == 403 { return .failed(.needsCredentials) }
      guard orgs.statusCode == 200 else { return .failed(.unexpectedStatus(orgs.statusCode)) }
      guard let org = try JSONDecoder().decode([Organization].self, from: orgs.data).first else {
        return .failed(.malformedResponse("no organizations"))
      }
      let url = URL(string: "https://claude.ai/api/organizations/\(org.uuid)/usage")!
      let usage = try await fetcher.get(url, cookie: cookie)
      guard usage.statusCode == 200 else { return .failed(.unexpectedStatus(usage.statusCode)) }
      return Self.parse(usage.data)
    } catch {
      return .failed(.malformedResponse(String(describing: error)))
    }
  }

  /// claude.ai exposes no token counts, so this reads the local Claude Code logs.
  public func lifetimeTokens() async -> Int? {
    await Task.detached(priority: .utility) { ClaudeCodeTokens.lifetimeTotal() }.value
  }

  static func parse(_ data: Data) -> ProviderStatus {
    guard let response = try? JSONDecoder().decode(UsageResponse.self, from: data) else {
      return .failed(.malformedResponse("unreadable usage payload"))
    }
    var metrics: [UsageMetric] = []
    if let window = response.five_hour, let used = window.utilization {
      metrics.append(UsageMetric(label: "5-hour", percentUsed: used, resetsAt: Timestamps.parse(window.resets_at),
        windowSeconds: 5 * 3600))
    }
    if let window = response.seven_day, let used = window.utilization {
      metrics.append(UsageMetric(label: "Weekly", percentUsed: used, resetsAt: Timestamps.parse(window.resets_at),
        windowSeconds: 7 * 86400))
    }
    guard !metrics.isEmpty else { return .failed(.malformedResponse("response had no usage windows")) }
    // The headline badge tracks the tighter of the two windows.
    return .ok(headline: metrics.map(\.percentUsed).max() ?? 0, metrics: metrics)
  }
}
