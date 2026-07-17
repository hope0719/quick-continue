// quick_continue.swift — Native macOS global hotkey + floating button
// Uses CGEventTap for hotkey detection (works in CLI tools)
// Uses osascript for keyboard simulation
//
// Compile:  swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue quick_continue.swift
// Run:      ./quick_continue            # Hotkey only (Cmd+Shift+J)
//           ./quick_continue --button   # Hotkey + floating click button
// Requires: Accessibility permission (System Settings → Privacy → Accessibility)

import CoreGraphics
import AppKit
import Foundation

let TEXT = "继续"
let KVK_ANSI_J: UInt32 = 0x26  // J key
let KVK_ANSI_B: UInt32 = 0x0B  // B key

let useButton = CommandLine.arguments.contains("--button")

// ─── Simulate input: save clipboard → paste → enter → restore ────

func simulateInput() {
    let pb = NSPasteboard.general

    // 0) Save current clipboard
    let saved = pb.string(forType: .string)

    // 1) Copy text to clipboard
    pb.clearContents()
    pb.setString(TEXT, forType: .string)

    Thread.sleep(forTimeInterval: 0.08)

    // 2) Simulate Cmd+V (paste) via osascript
    let pasteTask = Process()
    pasteTask.launchPath = "/usr/bin/osascript"
    pasteTask.arguments = ["-e", "tell application \"System Events\" to keystroke \"v\" using command down"]
    pasteTask.launch()
    pasteTask.waitUntilExit()

    Thread.sleep(forTimeInterval: 0.15)

    // 3) Simulate Enter via osascript
    let enterTask = Process()
    enterTask.launchPath = "/usr/bin/osascript"
    enterTask.arguments = ["-e", "tell application \"System Events\" to key code 36"]
    enterTask.launch()
    enterTask.waitUntilExit()

    // 4) Restore original clipboard content
    Thread.sleep(forTimeInterval: 0.1)
    pb.clearContents()
    if let saved = saved {
        pb.setString(saved, forType: .string)
    }
}

// ─── Log helper ──────────────────────────────────────────────────

func logTrigger(_ source: String) {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    let ts = f.string(from: Date())
    print("[\(ts)] \(source) → typing '\(TEXT)' + Enter")
    fflush(stdout)
    simulateInput()
}

// ─── Floating button window ──────────────────────────────────────

class FloatingButton {
    var window: NSPanel!
    var button: NSButton!
    var isDragging = false
    var dragStart: NSPoint = .zero
    var windowStart: NSPoint = .zero
    var contextMenu: NSMenu!

    init() {
        // Create borderless, floating panel
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 70, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating           // Always on top
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false

        // Rounded background view
        let bgView = NSView(frame: window.contentView!.bounds)
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        bgView.layer?.cornerRadius = 18
        bgView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(bgView)

        // Button
        button = NSButton(frame: NSRect(x: 0, y: 0, width: 70, height: 36))
        button.title = "▶ 继续"
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.boldSystemFont(ofSize: 12)
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(onClick)
        button.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(button)

        // Right-click context menu
        contextMenu = NSMenu(title: "Quick Continue")
        let hideItem = NSMenuItem(title: "隐藏", action: #selector(onHide), keyEquivalent: "")
        hideItem.target = self
        contextMenu.addItem(hideItem)
        let quitItem = NSMenuItem(title: "退出", action: #selector(onQuit), keyEquivalent: "")
        quitItem.target = self
        contextMenu.addItem(quitItem)

        // Add right-click handler
        let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(onRightClick(_:)))
        rightClickGesture.buttonMask = 0x2  // Right mouse button
        window.contentView!.addGestureRecognizer(rightClickGesture)

        // Position: bottom-right of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 90
            let y = screenFrame.minY + 60
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    @objc func onClick() {
        logTrigger("Button click")
        // Flash green feedback
        let bgView = window.contentView!.subviews[0]
        bgView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            bgView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        }
    }

    @objc func onRightClick(_ sender: NSClickGestureRecognizer) {
        let event = sender.location(in: window.contentView)
        contextMenu.popUp(positioning: nil, at: event, in: window.contentView)
    }

    @objc func onHide() {
        window.orderOut(nil)
    }

    @objc func onQuit() {
        NSApp.terminate(nil)
    }

    func show() {
        window.orderFrontRegardless()
    }

    func close() {
        window.close()
    }
}

var floatingBtn: FloatingButton?

// ─── CGEventTap callback (hotkey) ────────────────────────────────

var tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if keycode == Int64(KVK_ANSI_J) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        logTrigger("⌘+Shift+J")
    }

    // Toggle button visibility with Cmd+Shift+B
    if keycode == Int64(KVK_ANSI_B) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        if let btn = floatingBtn {
            if btn.window.isVisible {
                btn.window.orderOut(nil)
            } else {
                btn.window.orderFrontRegardless()
            }
        }
    }

    return Unmanaged.passRetained(event)
}

// ─── Main ────────────────────────────────────────────────────────

print("================================================")
print("  Quick Continue (native macOS)")
print("================================================")
print("  Hotkey : ⌘+Shift+J")
if useButton {
    print("  Button : Floating button (bottom-right)")
    print("  Toggle : ⌘+Shift+B (show/hide button)")
    print("  Menu   : Right-click button → 隐藏/退出")
}
print("  Text   : '\(TEXT)' + Enter")
print("------------------------------------------------")
print("  Clipboard: auto save & restore")
print("================================================")
fflush(stdout)

// Setup NSApplication (needed for floating window)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Create floating button if requested
if useButton {
    floatingBtn = FloatingButton()
    floatingBtn?.show()
}

// Create CGEventTap for keyboard events
let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: tapCallback,
    userInfo: nil
)

guard let tap = tap else {
    print("[ERROR] CGEventTap creation failed!")
    print("[!] Make sure Accessibility permission is enabled")
    print("[!] System Settings → Privacy & Security → Accessibility")
    exit(1)
}

// Add tap to run loop
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("  Ready.")
if useButton {
    print("  Press ⌘+Shift+J or click the floating ▶ button.")
} else {
    print("  Press ⌘+Shift+J to trigger.")
}
print("  Ctrl+C to quit.")
print("================================================")
fflush(stdout)

// Run app event loop
app.run()
