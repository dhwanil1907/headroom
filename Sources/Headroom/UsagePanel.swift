import HeadroomCore
import SwiftUI

struct UsagePanel: View {
  @ObservedObject var model: UsageModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      if model.isShowingSettings {
        SettingsView(model: model)
      } else {
        ForEach(model.providers, id: \.id) { provider in
          ProviderCard(
            provider: provider, status: model.statuses[provider.id],
            lifetimeTokens: model.lifetimeTokens[provider.id])
        }
      }
      HStack {
        Spacer()
        Button("Quit Headroom") { NSApplication.shared.terminate(nil) }
          .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .frame(width: 340)
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Headroom").font(.title3.bold())
        if let updated = model.lastUpdated {
          Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
      Button { model.isShowingSettings.toggle() } label: { Image(systemName: "gearshape") }
    }
    .buttonStyle(.borderless)
  }
}

struct ProviderStyle {
  let color: Color
  let symbol: String

  static func forProvider(_ id: String) -> ProviderStyle {
    id == "claude"
      ? ProviderStyle(color: Color(red: 0.85, green: 0.47, blue: 0.34), symbol: "sparkle")
      : ProviderStyle(color: Color(red: 0.38, green: 0.5, blue: 0.95), symbol: "cursorarrow.rays")
  }
}

struct ProviderCard: View {
  let provider: UsageProvider
  let status: ProviderStatus?
  let lifetimeTokens: Int?

  var body: some View {
    let style = ProviderStyle.forProvider(provider.id)
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        ProviderBadge(style: style)
        Text(provider.displayName).font(.headline)
        Spacer()
        if case .ok(let headline, _) = status {
          StatusPill(percent: headline, color: LevelColor.resolve(headline, base: style.color))
        }
      }
      content(style: style)
      if let lifetimeTokens {
        Divider()
        HStack {
          Label("Lifetime tokens", systemImage: "number").font(.subheadline.weight(.medium))
          Spacer()
          Text(TokenFormat.compact(lifetimeTokens)).font(.subheadline.weight(.semibold))
        }
        .help("\(lifetimeTokens.formatted()) tokens")
      }
    }
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  private func content(style: ProviderStyle) -> some View {
    switch status {
    case .none: Text("Checking usage…").font(.caption).foregroundStyle(.secondary)
    case .ok(_, let metrics): ForEach(metrics) { UsageBar(metric: $0, color: style.color) }
    case .unlimited: note("Unlimited plan - no usage limit to track")
    case .noLimit: note("No usage limit reported for this plan")
    case .failed(.needsCredentials): note("Sign in to see your usage")
    case .failed(.unexpectedStatus(let code)) where code == 401 || code == 403:
      note("Session expired - sign in again from Settings")
    case .failed(let error): note("\(provider.displayName) request failed: \(String(describing: error))")
    }
  }

  private func note(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary)
  }
}

struct ProviderBadge: View {
  let style: ProviderStyle

  var body: some View {
    Image(systemName: style.symbol)
      .foregroundStyle(.white)
      .frame(width: 26, height: 26)
      .background(style.color, in: Circle())
  }
}

enum LevelColor {
  static let amber = Color(red: 0.95, green: 0.68, blue: 0.2)
  static let red = Color(red: 0.9, green: 0.3, blue: 0.3)

  static func resolve(_ percent: Double, base: Color) -> Color {
    switch UsageLevel(percent: percent) {
    case .normal: return base
    case .warning: return amber
    case .critical: return red
    }
  }
}

struct StatusPill: View {
  let percent: Double
  let color: Color

  var body: some View {
    Text("\(Int(percent.rounded()))%")
      .font(.caption.bold()).foregroundStyle(color)
      .padding(.horizontal, 8).padding(.vertical, 3)
      .background(color.opacity(0.18), in: Capsule())
  }
}

struct UsageBar: View {
  let metric: UsageMetric
  let color: Color

  var body: some View {
    let barColor = LevelColor.resolve(metric.percentUsed, base: color)
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(metric.label).font(.subheadline.weight(.medium))
        Spacer()
        Text("\(Int(metric.percentUsed.rounded()))%").font(.subheadline.weight(.semibold))
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule().fill(barColor)
            .frame(width: proxy.size.width * min(max(metric.percentUsed / 100, 0), 1))
        }
      }
      .frame(height: 6)
      if let resets = metric.resetsAt {
        // Re-evaluated every 30s so the time-to-limit estimate stays current between refreshes.
        TimelineView(.periodic(from: .now, by: 30)) { context in
          VStack(alignment: .leading, spacing: 2) {
            Label(resetText(resets), systemImage: "clock")
            if let seconds = TimeToLimit.estimate(
              percentUsed: metric.percentUsed, windowSeconds: metric.windowSeconds,
              resetsAt: resets, now: context.date)
            {
              Label("At this pace, limit in ~\(Durations.compact(seconds))", systemImage: "flame")
                .foregroundStyle(LevelColor.amber)
            }
          }
          .font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
  }

  private func resetText(_ resets: Date) -> String {
    "Resets \(resets.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))"
  }
}
