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

        // Frameless style: transparent titlebar, content extends to top
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.styleMask.insert(.fullSizeContentView)
        self.isMovableByWindowBackground = true

        RegisterGeneratedPlugins(registry: flutterViewController)

        // IME + window control method channel
        let imeChannel = FlutterMethodChannel(
            name: "com.xjtu.genius/ime",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        imeChannel.setMethodCallHandler { [weak self] (call, result) in
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
            } else if call.method == "windowMinimize" {
                self?.miniaturize(nil)
                result(true)
            } else if call.method == "windowMaximize" {
                self?.zoom(nil)
                result(true)
            } else if call.method == "windowClose" {
                self?.close()
                result(true)
            } else if call.method == "windowDrag" {
                if let event = NSApp.currentEvent {
                    self?.performDrag(with: event)
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
