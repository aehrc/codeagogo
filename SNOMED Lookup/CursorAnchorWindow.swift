import Cocoa

final class CursorAnchorWindow {
    private var window: NSWindow?

    func showPopover(_ popover: NSPopover, at point: NSPoint, preferredEdge: NSRectEdge = .maxY) {
        let frame = NSRect(x: point.x, y: point.y, width: 1, height: 1)

        let w = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        
        w.collectionBehavior = [.moveToActiveSpace, .transient, .fullScreenAuxiliary]
        
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true

        let v = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        w.contentView = v

        self.window = w
        w.orderFront(nil) // do NOT make key

        popover.show(relativeTo: v.bounds, of: v, preferredEdge: preferredEdge)
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
