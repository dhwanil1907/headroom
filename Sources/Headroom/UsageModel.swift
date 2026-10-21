import HeadroomCore
import OSLog
import ServiceManagement
import SwiftUI

@MainActor
final class UsageModel: ObservableObject {
  @Published private(set) var statuses: [String: ProviderStatus] = [:]
  @Published private(set) var lifetimeTokens: [String: Int] = [:]
  @Published private(set) var lastUpdated: Date?
  @Published var isShowingSettings = false
  @Published var settingsError: String?
  @Published var launchesAtLogin = SMAppService.mainApp.status == .enabled

  let providers: [UsageProvider]
  private let keychain = KeychainStore()
  private let logger = Logger(subsystem: "com.headroom.app", category: "usage")
  private var timer: Timer?
  static let intervalOptions = [1, 5, 15]
  private static let intervalKey = "refreshIntervalMinutes"

  @Published var refreshMinutes: Int = {
    let saved = UserDefaults.standard.integer(forKey: UsageModel.intervalKey)
    return UsageModel.intervalOptions.contains(saved) ? saved : 5
  }() {
    didSet {
      UserDefaults.standard.set(refreshMinutes, forKey: Self.intervalKey)
      scheduleTimer()
    }
  }

  init(providers: [UsageProvider]? = nil) {
    self.providers = providers ?? ProviderRegistry.live(credentials: keychain)
    configureLaunchAtLoginOnce()
    Task { await refresh() }
    scheduleTimer()
  }

  private func scheduleTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshMinutes * 60), repeats: true) {
      [weak self] _ in
      Task { @MainActor in await self?.refresh() }
    }
  }

  /// The tightest usage across providers, for the menu bar.
  var worstPercent: Double? {
    statuses.values.compactMap { status -> Double? in
      if case .ok(let headline, _) = status { return headline }
      return nil
    }.max()
  }

  var menuBarSymbol: String {
    switch worstPercent ?? 0 {
    case ..<34: return "gauge.with.dots.needle.bottom.0percent"
    case ..<67: return "gauge.with.dots.needle.bottom.50percent"
    default: return "gauge.with.dots.needle.bottom.100percent"
    }
  }

  func refresh() async {
    for provider in providers {
      statuses[provider.id] = await provider.fetch()
      lifetimeTokens[provider.id] = await provider.lifetimeTokens()
    }
    lastUpdated = Date()
  }

  func saveSession(_ value: String, for provider: UsageProvider, key: String) {
    do {
      try keychain.save(value, provider: provider.id, key: key)
      settingsError = nil
      logger.info("captured session cookie for \(provider.id, privacy: .public)")
      Task { await refresh() }
    } catch {
      settingsError = "Keychain error: \(error)"
      logger.error("keychain save failed for \(provider.id, privacy: .public): \(String(describing: error), privacy: .public)")
    }
  }

  func signOut(_ provider: UsageProvider) {
    provider.credentialFields.forEach { keychain.delete(provider: provider.id, key: $0.key) }
    Task { await refresh() }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      launchesAtLogin = enabled
      settingsError = nil
    } catch {
      launchesAtLogin = SMAppService.mainApp.status == .enabled
      settingsError = "Allow Headroom in System Settings > General > Login Items"
      logger.error("launch at login failed: \(String(describing: error), privacy: .public)")
    }
  }

  private func configureLaunchAtLoginOnce() {
    let key = "didConfigureLaunchAtLogin"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    UserDefaults.standard.set(true, forKey: key)
    setLaunchAtLogin(true)
  }
}
