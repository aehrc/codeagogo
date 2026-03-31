// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa

final class CursorAnchorWindow {
    private var window: NSWindow?

    /// Public accessor for the underlying window (used to get window position).
    var nsWindow: NSWindow? { window }

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
