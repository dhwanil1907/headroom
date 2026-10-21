import HeadroomCore
import SwiftUI

@main
struct HeadroomApp: App {
  @StateObject private var model = UsageModel()

  var body: some Scene {
    MenuBarExtra {
      UsagePanel(model: model)
    } label: {
      HStack(spacing: 4) {
        Image(systemName: model.menuBarSymbol)
        if let worst = model.worstPercent {
          Text("\(Int(worst.rounded()))%").monospacedDigit()
        }
      }
    }
    .menuBarExtraStyle(.window)
  }
}
