import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformView = NSView
typealias PlatformColor = NSColor
typealias PlatformViewRepresentable = NSViewRepresentable

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#else
import UIKit
typealias PlatformImage = UIImage
typealias PlatformView = UIView
typealias PlatformColor = UIColor
typealias PlatformViewRepresentable = UIViewRepresentable

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif
