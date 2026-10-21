import Foundation
import Security

public protocol CredentialSource {
  func value(provider: String, key: String) -> String?
}

public struct StaticCredentials: CredentialSource {
  private let values: [String: String]

  public init(_ values: [String: String]) { self.values = values }

  public func value(provider: String, key: String) -> String? { values["\(provider).\(key)"] }
}

public enum KeychainError: Error, Equatable {
  case status(OSStatus)
}

/// Reads each item from the Keychain once per launch and serves later lookups from memory,
/// so macOS doesn't prompt for the login password on every refresh.
public final class KeychainStore: CredentialSource {
  public static let service = "com.headroom.credentials"

  private let lock = NSLock()
  private var cache: [String: String?] = [:]

  public init() {}

  private func query(provider: String, key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: "\(provider).\(key)",
    ]
  }

  public func value(provider: String, key: String) -> String? {
    let cacheKey = "\(provider).\(key)"
    lock.lock()
    defer { lock.unlock() }
    if let cached = cache[cacheKey] { return cached }
    let stored = readFromKeychain(provider: provider, key: key)
    // Only remember hits; a missing item may be saved later by the sign-in flow.
    if stored != nil { cache[cacheKey] = stored }
    return stored
  }

  private func readFromKeychain(provider: String, key: String) -> String? {
    var request = query(provider: provider, key: key)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  public func save(_ value: String, provider: String, key: String) throws {
    let base = query(provider: provider, key: key)
    SecItemDelete(base as CFDictionary)
    lock.lock()
    cache["\(provider).\(key)"] = .some(value)
    lock.unlock()
    var attributes = base
    attributes[kSecValueData as String] = Data(value.utf8)
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.status(status) }
  }

  public func delete(provider: String, key: String) {
    lock.lock()
    cache["\(provider).\(key)"] = nil
    lock.unlock()
    SecItemDelete(query(provider: provider, key: key) as CFDictionary)
  }
}
