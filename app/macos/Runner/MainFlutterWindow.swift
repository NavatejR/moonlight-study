import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Separate native title bar above the app content:
    //  - The strip stays a distinct region on top of the window (the Flutter
    //    view does NOT extend behind it, so the app UI starts below it).
    //  - titlebarAppearsTransparent + hidden title text let the window's
    //    backgroundColor show through, so the strip matches the app theme
    //    (pushed from Dart via the "com.moonlightstudy/window" channel).
    //  - Traffic lights keep their native position and behavior.
    // Note: deliberately NOT .fullSizeContentView — that would merge the
    // title bar into the content view instead of keeping it separate.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.isOpaque = true
    // Boot color matches the app's default dark ("midnight espresso") theme
    // until Dart pushes the live theme color.
    self.backgroundColor = NSColor(srgbRed: 0x24 / 255.0, green: 0x1A / 255.0, blue: 0x11 / 255.0, alpha: 1.0)

    // Dart -> native: keep the title-bar strip (window backing) in sync with
    // the Flutter theme (light/dark toggle in the app).
    let channel = FlutterMethodChannel(
      name: "com.moonlightstudy/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setWindowBackground":
        guard let args = call.arguments as? [String: Any],
              let r = args["r"] as? Int,
              let g = args["g"] as? Int,
              let b = args["b"] as? Int,
              let a = args["a"] as? Int else {
          result(FlutterError(code: "bad_args",
                              message: "expected {r,g,b,a} ints 0-255",
                              details: nil))
          return
        }
        DispatchQueue.main.async {
          // `self` is the window itself (MainFlutterWindow subclasses NSWindow).
          self.backgroundColor = NSColor(srgbRed: CGFloat(r) / 255.0,
                                         green: CGFloat(g) / 255.0,
                                         blue: CGFloat(b) / 255.0,
                                         alpha: CGFloat(a) / 255.0)
          self.isOpaque = true
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
