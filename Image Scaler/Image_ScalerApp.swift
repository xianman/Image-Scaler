//
//  Image_ScalerApp.swift
//  Image Scaler
//
//  Created by Christian Kittle on 2/9/26.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func application(_ application: NSApplication, open urls: [URL]) {
        handleIncoming(urls)
    }

    func handleIncoming(_ urls: [URL]) {
        // Separate custom URL scheme from file URLs
        for url in urls {
            if url.scheme == "image-scaler" {
                handleURLScheme(url)
            } else {
                model?.addFiles([url])
            }
        }
    }

    private func handleURLScheme(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let encoded = queryItems.first(where: { $0.name == "paths" })?.value,
              let data = Data(base64Encoded: encoded),
              let paths = String(data: data, encoding: .utf8) else { return }

        let fileURLs = paths.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
        model?.addFiles(fileURLs)
    }
}

@main
struct Image_ScalerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    appDelegate.model = model
                    model.ingestCommandLineFiles()
                }
        }
    }
}
