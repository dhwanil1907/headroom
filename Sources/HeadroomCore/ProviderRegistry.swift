import Foundation

public enum ProviderRegistry {
  public static func live(credentials: CredentialSource = KeychainStore()) -> [UsageProvider] {
    [ClaudeProvider(credentials: credentials), CursorProvider(credentials: credentials)]
  }
}
