import AppKit
import PorterCore

/// App icons at menu/menu-bar sizes, cached per browser.
@MainActor
final class IconProvider {
    private var cache: [String: NSImage] = [:]

    func icon(for browser: Browser, size: CGFloat, monochrome: Bool = false) -> NSImage {
        let key = "\(browser.id)|\(browser.url.path)|\(size)|\(monochrome)"
        if let cached = cache[key] { return cached }

        let source = NSWorkspace.shared.icon(forFile: browser.url.path)
        let side = NSSize(width: size, height: size)
        // Drawn lazily so it stays sharp on Retina and non-Retina screens alike.
        let image = NSImage(size: side, flipped: false) { rect in
            source.draw(in: rect)
            if monochrome {
                // Strip saturation, then clip back to the icon's own shape.
                NSColor.gray.setFill()
                rect.fill(using: .saturation)
                source.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            }
            return true
        }
        image.accessibilityDescription = browser.name
        cache[key] = image
        return image
    }

    func menuBarImage(for browser: Browser?, style: IconStyle) -> NSImage {
        if let browser {
            return icon(for: browser, size: 18, monochrome: style == .monochrome)
        }
        let fallback = NSImage(systemSymbolName: "globe", accessibilityDescription: String(localized: "Default browser unknown")) ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
