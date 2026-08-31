import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    registerMusicFolderChannel(controller: controller)
  }

  /// Handles picking and persisting a security-scoped music folder so the
  /// sandboxed app can read tracks again on later launches.
  private func registerMusicFolderChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "moonlight/music_folder",
      binaryMessenger: controller.engine.binaryMessenger)

    channel.setMethodCallHandler { [weak controller] call, result in
      guard let controller else {
        result(FlutterError(code: "no_controller", message: "Flutter controller is gone", details: nil))
        return
      }
      switch call.method {
      case "pickFolder":
        MusicFolderStore.pickFolder(result: result, controller: controller)
      case "resolveFolder":
        MusicFolderStore.resolveFolder(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Persists a bookmarked folder reference in the sandboxed container.
enum MusicFolderStore {
  private static let defaultsKey = "music_folder_bookmark"

  static func pickFolder(result: @escaping FlutterResult, controller: FlutterViewController) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Music Folder"
    panel.message = "Moonlight will scan this folder for music tracks."
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      if let bookmark = createBookmark(url: url) {
        saveBookmark(bookmark)
      }
      print("music folder picked: \(url.path)")
      result(url.path)
    }
  }

  static func resolveFolder(result: @escaping FlutterResult) {
    guard let bookmark = loadBookmark() else {
      result(nil)
      return
    }
    var stale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &stale)
      if stale {
        let _ = url.startAccessingSecurityScopedResource()
        if let fresh = createBookmark(url: url) {
          saveBookmark(fresh)
        }
        url.stopAccessingSecurityScopedResource()
      }
      let success = url.startAccessingSecurityScopedResource()
      print("music folder resolve ok=\(success) path=\(url.path)")
      result(success ? url.path : nil)
    } catch {
      print("music folder resolve error: \(error.localizedDescription)")
      result(nil)
    }
  }

  private static func createBookmark(url: URL) -> Data? {
    return try? url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil)
  }

  private static func saveBookmark(_ data: Data) {
    UserDefaults.standard.set(data, forKey: defaultsKey)
  }

  private static func loadBookmark() -> Data? {
    return UserDefaults.standard.data(forKey: defaultsKey)
  }
}
