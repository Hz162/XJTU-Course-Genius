import Cocoa
import FlutterMacOS

// Saved input source for IME restore
var savedInputSource: TISInputSource?

func switchImeToEnglish() -> Bool {
    guard let sources = TISCreateInputSourceList(nil, false)?
        .takeRetainedValue() as? [TISInputSource] else {
        return false
    }
    for source in sources {
        let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        if ptr != nil {
            let sourceId = Unmanaged<CFString>
                .fromOpaque(ptr!).takeUnretainedValue() as String
            if sourceId.contains("com.apple.keylayout.US") {
                return TISSelectInputSource(source) == noErr
            }
        }
    }
    return false
}

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        // IME method channel: switch keyboard to English on macOS
        let imeChannel = FlutterMethodChannel(
            name: "com.xjtu.genius/ime",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        imeChannel.setMethodCallHandler { (call, result) in
            if call.method == "saveCurrentIme" {
                savedInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
                result(true)
            } else if call.method == "switchToEnglish" {
                let ok = switchImeToEnglish()
                result(ok)
            } else if call.method == "restoreIme" {
                if let source = savedInputSource {
                    TISSelectInputSource(source)
                    savedInputSource = nil
                }
                result(true)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // Restore IME when window loses key (user switches to another app)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: nil) { _ in
                if let source = savedInputSource {
                    TISSelectInputSource(source)
                    // Keep savedInputSource so we can switch back on reactivation
                }
            }

        // Switch back to English when window becomes key again
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: self,
            queue: nil) { _ in
                if savedInputSource != nil {
                    _ = switchImeToEnglish()
                }
            }

        super.awakeFromNib()
    }
}
