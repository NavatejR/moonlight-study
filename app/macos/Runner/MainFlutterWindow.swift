import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Frameless themed title bar: hide the stock gray chrome, let the
    // Flutter UI paint the espresso/crema theme up to the top edge while
    // preserving the native traffic-light buttons and window dragging.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isOpaque = false
    self.backgroundColor = .clear

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // A subtle escape hatch so the window can still be closed via the
  // traffic lights even in a frameless layout.
  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
  }
}