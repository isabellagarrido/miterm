import AppKit
import Testing
@testable import Ghostty

@Suite @MainActor
struct StackEmojiPickerTests {
    @Test func nativeInputContextReceivesEmojiWithoutEditingStackName() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let name = NSTextField(string: "My Stack")
        name.frame = NSRect(x: 10, y: 10, width: 200, height: 24)
        let picker = StackEmojiPickerButton(frame: NSRect(x: 220, y: 10, width: 120, height: 24))
        window.contentView?.addSubview(name)
        window.contentView?.addSubview(picker)
        var selected: String? = "📚"
        picker.onSelection = { selected = $0 }

        #expect(window.makeFirstResponder(name))
        #expect(window.makeFirstResponder(picker))
        let context = try #require(picker.inputContext)
        context.client.insertText(NSAttributedString(string: "👩🏽‍💻"), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(selected == "👩🏽‍💻")
        #expect(name.stringValue == "My Stack")
    }
}
