import AppKit
import HeadroomCore
import WebKit

/// Hosts a web login and hands back the session cookie as soon as the site sets it.
final class LoginWindowController: NSWindowController, NSWindowDelegate, WKHTTPCookieStoreObserver {
  private static var open: [LoginWindowController] = []

  private let spec: LoginSpec
  private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
  private let onSession: (String) -> Void

  static func present(spec: LoginSpec, title: String, onSession: @escaping (String) -> Void) {
    let controller = LoginWindowController(spec: spec, title: title, onSession: onSession)
    open.append(controller)
    controller.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private init(spec: LoginSpec, title: String, onSession: @escaping (String) -> Void) {
    self.spec = spec
    self.onSession = onSession
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.title = title
    window.contentView = webView
    window.center()
    super.init(window: window)
    window.delegate = self
    webView.configuration.websiteDataStore.httpCookieStore.add(self)
    webView.load(URLRequest(url: spec.url))
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
    cookieStore.getAllCookies { [weak self] cookies in
      guard let self,
        let match = cookies.first(where: {
          $0.name == self.spec.cookieName && $0.domain.hasSuffix(self.spec.cookieDomain)
        })
      else { return }
      self.onSession(match.value)
      self.window?.close()
    }
  }

  func windowWillClose(_ notification: Notification) {
    webView.configuration.websiteDataStore.httpCookieStore.remove(self)
    Self.open.removeAll { $0 === self }
  }
}
