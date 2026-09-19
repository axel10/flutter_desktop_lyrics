import Cocoa
import FlutterMacOS

public class FlutterDesktopLyricsPlugin: NSObject, FlutterPlugin {
  private weak var registrar: FlutterPluginRegistrar?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_desktop_lyrics", binaryMessenger: registrar.messenger)
    let instance = FlutterDesktopLyricsPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var targetWindow: NSWindow? {
    if let w = registrar?.view?.window {
      return w
    }
    if let view = registrar?.view {
      for window in NSApp.windows {
        if window.contentView == view || window.contentViewController?.view == view {
          return window
        }
      }
    }
    return NSApp.keyWindow
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

    case "initializeLyricsWindow":
      DispatchQueue.main.async { [weak self] in
        guard let self = self, let window = self.targetWindow else {
          result(FlutterError(code: "NO_WINDOW", message: "Could not obtain native window", details: nil))
          return
        }

        // 安全检查：如果检测到是主窗口（例如在多窗口生命周期分离初期），切勿修改主窗口
        if let appDelegate = NSApplication.shared.delegate as? FlutterAppDelegate,
           let mainWindow = appDelegate.mainFlutterWindow,
           window == mainWindow {
          result(FlutterError(code: "INVALID_TARGET", message: "Target window is main window", details: nil))
          return
        }

        // 1. 无边框、透明背景、无阴影、非激活面板（nonactivatingPanel 阻止点击时激活宿主应用唤起主窗口）
        window.styleMask = [.borderless, .nonactivatingPanel]
        if let panel = window as? NSPanel {
          panel.hidesOnDeactivate = false
          panel.isFloatingPanel = false
          panel.becomesKeyOnlyIfNeeded = true
        }
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true

        // 2. 系统级置顶浮动窗口（statusBar 级别高于所有第三方应用窗口，确保宿主应用失焦后歌词依然置顶）
        window.level = .statusBar

        // 3. 允许出现在所有桌面空间（Spaces）、全屏应用之上，且不参与窗口切换循环 (Cmd+`)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        // 4. 透明 Flutter 渲染视图层
        if let view = self.registrar?.view {
          view.wantsLayer = true
          view.layer?.backgroundColor = NSColor.clear.cgColor
          view.layer?.isOpaque = false
        }

        let args = call.arguments as? [String: Any] ?? [:]
        let w = (args["width"] as? NSNumber)?.doubleValue ?? 920.0
        let h = (args["height"] as? NSNumber)?.doubleValue ?? 150.0
        let customX = (args["x"] as? NSNumber)?.doubleValue
        let customY = (args["y"] as? NSNumber)?.doubleValue

        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080.0

        let finalX: CGFloat
        let finalY: CGFloat

        if let cx = customX, let cy = customY {
          finalX = CGFloat(cx)
          finalY = primaryScreenHeight - CGFloat(cy) - CGFloat(h)
        } else {
          finalX = visibleFrame.origin.x + (visibleFrame.width - CGFloat(w)) / 2.0
          finalY = visibleFrame.origin.y + 60.0
        }

        window.setFrame(NSRect(x: finalX, y: finalY, width: CGFloat(w), height: CGFloat(h)), display: true)
        window.orderFront(nil)
        window.setIsVisible(true)

        result(true)
      }

    case "setClickThrough":
      var enabled = false
      if let val = call.arguments as? Bool {
        enabled = val
      } else if let dict = call.arguments as? [String: Any], let val = dict["enabled"] as? Bool {
        enabled = val
      }
      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(false)
          return
        }
        window.ignoresMouseEvents = enabled
        result(true)
      }

    case "setAlwaysOnTop":
      let isAlwaysOnTop = (call.arguments as? Bool) ?? true
      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(false)
          return
        }
        window.level = isAlwaysOnTop ? .statusBar : .normal
        result(true)
      }

    case "startDragging":
      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(false)
          return
        }
        result(true)
        if let event = NSApp.currentEvent ?? window.currentEvent {
          window.performDrag(with: event)
        }
      }

    case "setWindowBounds":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected map for setWindowBounds", details: nil))
        return
      }
      let x = (args["x"] as? NSNumber)?.doubleValue ?? 0.0
      let y = (args["y"] as? NSNumber)?.doubleValue ?? 0.0
      let w = (args["width"] as? NSNumber)?.doubleValue ?? 920.0
      let h = (args["height"] as? NSNumber)?.doubleValue ?? 150.0

      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(false)
          return
        }
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        let cocoaY = primaryScreenHeight - CGFloat(y) - CGFloat(h)
        window.setFrame(NSRect(x: CGFloat(x), y: cocoaY, width: CGFloat(w), height: CGFloat(h)), display: true)
        result(true)
      }

    case "getWindowBounds":
      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(nil)
          return
        }
        let frame = window.frame
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        let topY = primaryScreenHeight - frame.origin.y - frame.size.height
        let bounds: [String: Double] = [
          "x": Double(frame.origin.x),
          "y": Double(topY),
          "width": Double(frame.size.width),
          "height": Double(frame.size.height)
        ]
        result(bounds)
      }

    case "showWindow":
      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(false)
          return
        }
        // 浮动歌词面板显示时使用 orderFront(nil) 而不是 makeKeyAndOrderFront，避免强行夺取用户前台焦点
        window.orderFront(nil)
        window.setIsVisible(true)
        result(true)
      }

    case "hideWindow":
      DispatchQueue.main.async { [weak self] in
        guard let window = self?.targetWindow else {
          result(false)
          return
        }
        window.orderOut(nil)
        result(true)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
