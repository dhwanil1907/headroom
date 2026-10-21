import Foundation

public struct FetchResult {
  public let data: Data
  public let statusCode: Int

  public init(data: Data, statusCode: Int) {
    self.data = data
    self.statusCode = statusCode
  }
}

public protocol Fetcher {
  func get(_ url: URL, cookie: String) async throws -> FetchResult
}

public struct URLSessionFetcher: Fetcher {
  public init() {}

  public func get(_ url: URL, cookie: String) async throws -> FetchResult {
    try await send(URLRequest(url: url), cookie: cookie)
  }

  private func send(_ base: URLRequest, cookie: String) async throws -> FetchResult {
    var request = base
    request.setValue(cookie, forHTTPHeaderField: "Cookie")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    return FetchResult(data: data, statusCode: status)
  }
}
