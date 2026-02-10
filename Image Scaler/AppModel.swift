//
//  AppModel.swift
//  Image Scaler
//
//  Created by Christian Kittle on 2/9/26.
//

import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var files: [URL] = []

    private static let supportedImageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp", "heic", "avif"
    ]

    func addFiles(_ urls: [URL]) {
        var set = Set(files)
        for u in urls where FileManager.default.fileExists(atPath: u.path) {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir)
            if isDir.boolValue {
                let enumerator = FileManager.default.enumerator(
                    at: u,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    if Self.supportedImageExtensions.contains(fileURL.pathExtension.lowercased()) {
                        set.insert(fileURL)
                    }
                }
            } else {
                set.insert(u)
            }
        }
        files = Array(set).sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    func ingestCommandLineFiles() {
        // Expect: --from-finder <file1> <file2> ...
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--from-finder") else { return }
        let paths = args.suffix(from: args.index(after: idx))
        let urls = paths.map { URL(fileURLWithPath: $0) }
        addFiles(urls)
    }
}
