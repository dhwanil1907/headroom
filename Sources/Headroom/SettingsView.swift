import HeadroomCore
import SwiftUI

// Plain ObservableObject instead of @State: the @State macro needs Xcode's SwiftUI plugin.
final class ManualEntry: ObservableObject {
  @Published var values: [String: String] = [:]
}

struct SettingsView: View {
  @ObservedObject var model: UsageModel
  @StateObject private var entry = ManualEntry()

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle("Launch at login", isOn: Binding(get: { model.launchesAtLogin }, set: model.setLaunchAtLogin))
      Picker("Refresh every", selection: $model.refreshMinutes) {
        ForEach(UsageModel.intervalOptions, id: \.self) { Text("\($0) min").tag($0) }
      }
      ForEach(model.providers, id: \.id) { provider in
        VStack(alignment: .leading, spacing: 6) {
          Text(provider.displayName).font(.headline)
          HStack {
            if let login = provider.login {
              Button("Sign in…") { signIn(provider, login) }
            }
            Button("Sign out") { model.signOut(provider) }
          }
          ForEach(provider.credentialFields, id: \.key) { field in
            HStack {
              SecureField(field.label, text: binding(provider, field), prompt: Text(field.placeholder))
              Button("Save") { save(provider, field) }
            }
          }
        }
      }
      if let error = model.settingsError {
        Text(error).font(.caption).foregroundStyle(.red)
      }
    }
  }

  private func binding(_ provider: UsageProvider, _ field: CredentialField) -> Binding<String> {
    let key = "\(provider.id).\(field.key)"
    return Binding(get: { entry.values[key, default: ""] }, set: { entry.values[key] = $0 })
  }

  private func save(_ provider: UsageProvider, _ field: CredentialField) {
    let key = "\(provider.id).\(field.key)"
    guard let value = entry.values[key], !value.isEmpty else { return }
    model.saveSession(value, for: provider, key: field.key)
    entry.values[key] = ""
  }

  private func signIn(_ provider: UsageProvider, _ login: LoginSpec) {
    LoginWindowController.present(spec: login, title: "Sign in to \(provider.displayName)") { token in
      model.saveSession(token, for: provider, key: provider.credentialFields[0].key)
    }
  }
}
