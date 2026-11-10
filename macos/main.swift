// HP-11C — standalone macOS app.
// A native window hosting index.html in WKWebView. The page is served through a
// custom "hp11c://" scheme so it has a stable origin and its localStorage
// (stack, registers, display mode) persists between launches.

import Cocoa
import WebKit

final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var name = url.path.isEmpty || url.path == "/" ? "index.html" : String(url.path.dropFirst())
        if name.contains("..") { name = "index.html" }
        guard let res = Bundle.main.resourceURL?.appendingPathComponent("web").appendingPathComponent(name),
              let data = try? Data(contentsOf: res) else {
            task.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist))
            return
        }
        let mime: String
        switch res.pathExtension.lowercased() {
        case "html": mime = "text/html"
        case "js":   mime = "text/javascript"
        case "css":  mime = "text/css"
        case "png":  mime = "image/png"
        case "webp": mime = "image/webp"
        default:     mime = "application/octet-stream"
        }
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "\(mime); charset=utf-8",
                                                  "Content-Length": "\(data.count)"])!
        task.didReceive(resp)
        task.didReceive(data)
        task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

/// Invisible strip over the title-bar area: the web view would otherwise swallow
/// the clicks, so this lets the window be dragged (and zoomed by double-click).
final class DragBar: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { window?.performZoom(nil); return }
        window?.performDrag(with: event)
    }
    override var mouseDownCanMoveWindow: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    let schemeHandler = BundleSchemeHandler()
    var lastMouseDown: NSEvent?

    /// The page posts "drag" when a press lands outside the keys: move the window.
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "save", let json = message.body as? String {
            UserDefaults.standard.set(json, forKey: "calculatorState")   // stack, registers, modes
            return
        }
        guard message.name == "drag", let ev = lastMouseDown else { return }
        window.performDrag(with: ev)
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "hp11c")
        config.websiteDataStore = .default()          // persistent localStorage
        // tell the page it runs inside the app (extra top margin for the title-bar buttons)
        config.userContentController.add(self, name: "drag")
        config.userContentController.add(self, name: "save")
        // restore the previous session's state before the page's own script runs
        if let saved = UserDefaults.standard.string(forKey: "calculatorState"),
           let b64 = saved.data(using: .utf8)?.base64EncodedString() {
            config.userContentController.addUserScript(WKUserScript(
                source: "window.__HP11C_STATE = decodeURIComponent(escape(atob('\(b64)')));",
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] ev in
            self?.lastMouseDown = ev; return ev
        }
        config.userContentController.addUserScript(WKUserScript(
            source: "document.documentElement.classList.add('app')",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))

        // calculator (1.6:1) + side panel, with thin margins — see .wrapper in index.html
        let frame = NSRect(x: 0, y: 0, width: 1304, height: 700)
        webView = WKWebView(frame: frame, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")   // no white flash on launch
        webView.allowsMagnification = false

        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "HP-11C"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0x1a/255.0, green: 0x20/255.0, blue: 0x1d/255.0, alpha: 1)
        window.isMovableByWindowBackground = true
        window.contentAspectRatio = frame.size               // keeps the margins thin when resizing
        window.contentMinSize = NSSize(width: 652, height: 350)
        let container = NSView(frame: frame)
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        let barHeight: CGFloat = 30                        // = --mt in index.html (html.app)
        let bar = DragBar(frame: NSRect(x: 0, y: frame.height - barHeight, width: frame.width, height: barHeight))
        bar.autoresizingMask = [.width, .minYMargin]
        container.addSubview(bar)                          // above the web view
        window.contentView = container
        window.delegate = self
        window.setFrameAutosaveName("HP11CWindow")     // remembers size & position
        if !window.setFrameUsingName("HP11CWindow") { window.center() }

        webView.load(URLRequest(url: URL(string: "hp11c://app/index.html")!))
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)                 // keyboard shortcuts go to the calculator
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "À propos de HP-11C",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Masquer HP-11C", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quitter HP-11C", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Édition")
        edit.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editItem.submenu = edit

        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Fenêtre")
        win.addItem(withTitle: "Réduire", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Fermer", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = win
        NSApp.windowsMenu = win

        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
