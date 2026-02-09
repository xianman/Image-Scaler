//
//  FinderSync.swift
//  ImageScalerFinderSync
//
//  Created by Christian Kittle on 2/9/26.
//

import Cocoa
import FinderSync
import os.log

final class FinderSync: FIFinderSync {

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinderExt", category: "FinderSync")

    override init() {
        super.init()

        // Monitor "/" so the context menu appears everywhere.
        // In a sandboxed extension, FileManager APIs return sandbox container
        // paths, not real paths, so we use a literal root URL instead.
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/")
        ]

        log.info("FinderSync init — observing /")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: "Scale Images…", action: #selector(scaleImages(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func scaleImages(_ sender: Any?) {
        let controller = FIFinderSyncController.default()
        let urls = controller.selectedItemURLs() ?? []
        log.info("Clicked. selectedItemURLs=\(urls.count) targetedURL=\(controller.targetedURL()?.path ?? "nil")")

        guard !urls.isEmpty else {
            NSSound.beep()
            return
        }

        launchHostApp(with: urls)
    }

    private func launchHostApp(with urls: [URL]) {
        // Encode file paths as base64 in a custom URL scheme.
        // NSWorkspace.open(URL) for URL schemes is allowed from sandboxed extensions.
        let paths = urls.map { $0.path }.joined(separator: "\n")
        guard let data = paths.data(using: .utf8) else { return }
        let encoded = data.base64EncodedString()

        guard let url = URL(string: "image-scaler://open?paths=\(encoded)") else { return }
        log.info("Opening URL scheme with \(urls.count) files")
        NSWorkspace.shared.open(url)
    }
}
