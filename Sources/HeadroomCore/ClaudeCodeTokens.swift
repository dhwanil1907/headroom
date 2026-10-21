import Foundation

/// Lifetime Claude Code token usage, counted the same way as Claude Code's `/stats` screen.
public enum ClaudeCodeTokens {
  struct Usage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?

    var total: Int {
      (input_tokens ?? 0) + (output_tokens ?? 0) + (cache_creation_input_tokens ?? 0)
        + (cache_read_input_tokens ?? 0)
    }
  }

  struct Entry: Decodable {
    struct Message: Decodable { let usage: Usage? }
    let message: Message?
  }

  struct ModelUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?

    var total: Int {
      (inputTokens ?? 0) + (outputTokens ?? 0) + (cacheReadInputTokens ?? 0)
        + (cacheCreationInputTokens ?? 0)
    }
  }

  struct StatsCache: Decodable { let modelUsage: [String: ModelUsage]? }

  private static var claudeHome: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
  }

  public static var defaultStatsFile: URL { claudeHome.appendingPathComponent("stats-cache.json") }
  public static var defaultLogRoot: URL { claudeHome.appendingPathComponent("projects") }

  /// The stats cache remembers history whose logs were cleaned up, but Claude Code only refreshes
  /// it occasionally, so it goes stale. The session logs are always current but may be incomplete.
  /// Whichever is larger is the better estimate.
  public static func lifetimeTotal(
    statsFile: URL = defaultStatsFile, logRoot: URL = defaultLogRoot
  ) -> Int? {
    [totalFromStatsCache(statsFile), totalFromLogs(logRoot)].compactMap { $0 }.max()
  }

  static func totalFromStatsCache(_ file: URL) -> Int? {
    guard let data = try? Data(contentsOf: file),
      let models = (try? JSONDecoder().decode(StatsCache.self, from: data))?.modelUsage,
      !models.isEmpty
    else { return nil }
    return models.values.reduce(0) { $0 + $1.total }
  }

  static func totalFromLogs(_ root: URL) -> Int? {
    guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
      return nil
    }
    var total = 0
    var sawLog = false
    let decoder = JSONDecoder()
    for case let file as URL in files where file.pathExtension == "jsonl" {
      guard let contents = try? String(contentsOf: file, encoding: .utf8) else { continue }
      sawLog = true
      for line in contents.split(separator: "\n") where line.contains("\"usage\"") {
        if let usage = (try? decoder.decode(Entry.self, from: Data(line.utf8)))?.message?.usage {
          total += usage.total
        }
      }
    }
    return sawLog ? total : nil
  }
}
