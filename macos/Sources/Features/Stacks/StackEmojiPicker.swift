import AppKit
import SwiftUI

/// A button that receives selections directly from macOS Emoji & Symbols.
/// Making the button the text input client prevents the palette from inserting
/// its selection into the Stack name or another focused editor field.
struct StackEmojiPicker: NSViewRepresentable {
    @Binding var emoji: String?

    func makeNSView(context: Context) -> StackEmojiPickerButton {
        let button = StackEmojiPickerButton()
        button.bezelStyle = .rounded
        button.target = button
        button.action = #selector(StackEmojiPickerButton.chooseEmoji(_:))
        button.toolTip = "Choose an icon with macOS Emoji & Symbols"
        button.setAccessibilityLabel("Choose Stack emoji")
        return button
    }

    func updateNSView(_ button: StackEmojiPickerButton, context: Context) {
        button.title = emoji ?? "Choose emoji…"
        button.setAccessibilityValue(emoji ?? "None")
        button.onSelection = { emoji = $0 }
    }
}

final class StackEmojiPickerButton: NSButton, NSTextInputClient {
    var onSelection: ((String) -> Void)?
    private var markedText = ""

    override var acceptsFirstResponder: Bool { true }

    @objc func chooseEmoji(_ sender: Any?) {
        guard window?.makeFirstResponder(self) == true else { return }
        NSApp.orderFrontCharacterPalette(sender)
    }

    override func keyDown(with event: NSEvent) {
        // Keep normal button activation and keyboard navigation. Other input is
        // handled by the native input context, including palette insertions.
        if event.keyCode == 49 || event.keyCode == 36 {
            chooseEmoji(self)
        } else {
            interpretKeyEvents([event])
        }
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        let value = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        markedText = ""
        guard value.count == 1,
              value.unicodeScalars.contains(where: { $0.properties.isEmoji }) else { return }
        onSelection?(value)
    }

    func hasMarkedText() -> Bool { !markedText.isEmpty }

    func markedRange() -> NSRange {
        markedText.isEmpty ? NSRange(location: NSNotFound, length: 0)
            : NSRange(location: 0, length: markedText.utf16.count)
    }

    func selectedRange() -> NSRange { NSRange(location: 0, length: 0) }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        markedText = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
    }

    func unmarkText() { markedText = "" }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        return nil
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: 0, length: 0)
        return window?.convertToScreen(convert(bounds, to: nil)) ?? .zero
    }

    func characterIndex(for point: NSPoint) -> Int { 0 }

    override func doCommand(by selector: Selector) {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            window?.makeFirstResponder(nil)
        } else {
            super.doCommand(by: selector)
        }
    }
}
