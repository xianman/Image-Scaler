//
//  ContentView.swift
//  Image Scaler
//
//  Created by Christian Kittle on 2/9/26.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

enum ScaleMode: String, CaseIterable, Identifiable {
    case triple = "UI Assets (@1x/@2x/@3x)"
    case singleWidth = "Single (fit width)"
    case box = "Single (fit within box)"
    var id: String { rawValue }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case png = "PNG"
    case heic = "HEIC"
    case avif = "AVIF"
    var id: String { rawValue }

    var sipsFormat: String {
        switch self {
        case .jpg: return "jpeg"
        case .png: return "png"
        case .heic: return "heic"
        case .avif: return "avif"
        }
    }

    var fileExt: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .avif: return "avif"
        }
    }
}

enum OutputDestination: String, CaseIterable, Identifiable {
    case subfolder = "Subfolder"
    case inPlace = "In Place"
    case chooseFolder = "Choose Folder…"
    var id: String { rawValue }
}

struct SavedPreset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var base: Int
}

final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published var presets: [SavedPreset] {
        didSet { save() }
    }

    private static let key = "savedPresets"

    private static let defaults: [SavedPreset] = [
        .init(name: "Tab Bar Item", base: 30),
        .init(name: "Custom Table/List Icon", base: 48),
        .init(name: "Small Button/Icon", base: 20),
        .init(name: "Nav Bar/Toolbar Glyph", base: 24),
        .init(name: "Large Icon", base: 64),
        .init(name: "Book Icon", base: 128),
    ]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([SavedPreset].self, from: data) {
            presets = decoded
        } else {
            presets = Self.defaults
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func label(for preset: SavedPreset) -> String {
        let b = preset.base
        return "\(preset.name) (\(b)px \u{2192} \(b)/\(b*2)/\(b*3))"
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var presetStore = PresetStore.shared

    @AppStorage("scaleMode") private var mode: ScaleMode = .singleWidth
    @AppStorage("presetIndex") private var presetIndex: Int = 1
    @AppStorage("customBase") private var customBase: String = "48"
    @State private var showingPresetEditor = false

    @AppStorage("maxWidth") private var width: String = "1024"
    @AppStorage("maxHeight") private var height: String = "0"

    @AppStorage("neverUpscale") private var neverUpscale: Bool = true
    @AppStorage("preserveAspect") private var preserveAspect: Bool = true
    @AppStorage("outputFormat") private var outFormat: OutputFormat = .jpg

    @AppStorage("jpegQuality") private var jpegQuality: Double = 90
    @AppStorage("keepOriginalName") private var keepOriginalName: Bool = false
    @AppStorage("outputDestination") private var outputDestination: OutputDestination = .subfolder
    @AppStorage("sendToImageOptim") private var sendToImageOptim: Bool = false
    @AppStorage("stripMetadata") private var stripMetadata: Bool = false

    @State private var customOutputDir: URL? = {
        guard let data = UserDefaults.standard.data(forKey: "customOutputDirBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale) else { return nil }
        if stale { return nil }
        return url
    }()

    private var isCustomPreset: Bool {
        presetIndex >= presetStore.presets.count
    }

    private var selectedBase: Int? {
        guard !isCustomPreset else { return nil }
        return presetStore.presets[presetIndex].base
    }

    @State private var isRunning = false
    @State private var isCancelled = false
    @State private var log: String = ""
    @State private var processedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var lastOutputURLs: [URL] = []
    @State private var fileSelection: Set<URL> = []

    var body: some View {
        VStack(spacing: 14) {
            header

            HStack(alignment: .top, spacing: 16) {
                options
                fileList
            }
            .frame(minHeight: 320)

            footer
        }
        .padding(16)
        .frame(minWidth: 980, minHeight: 640)
        .onReceive(NotificationCenter.default.publisher(for: .openImages)) { _ in
            chooseImages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectAllFiles)) { _ in
            fileSelection = Set(model.files)
        }
    }

    private var header: some View {
        HStack {
            Text("Image Scaler")
                .font(.system(size: 22, weight: .bold))
            Spacer()
            Button("Choose Images…") { chooseImages() }
            Button("Clear") { model.files.removeAll() }
                .disabled(model.files.isEmpty)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Scaling") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Mode", selection: $mode) {
                        ForEach(ScaleMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    if mode == .triple {
                        HStack {
                            Picker("UI Preset", selection: $presetIndex) {
                                ForEach(presetStore.presets.indices, id: \.self) { i in
                                    Text(presetStore.label(for: presetStore.presets[i])).tag(i)
                                }
                                Divider()
                                Text("Custom\u{2026}").tag(presetStore.presets.count)
                            }
                            .pickerStyle(.menu)

                            Button {
                                showingPresetEditor = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("Edit Presets")
                        }
                        .sheet(isPresented: $showingPresetEditor) {
                            PresetEditorView(store: presetStore)
                        }

                        if isCustomPreset {
                            HStack {
                                Text("Base px")
                                Spacer()
                                TextField("48", text: $customBase)
                                    .frame(width: 90)
                                    .textFieldStyle(.roundedBorder)
                            }
                        } else {
                            HStack {
                                Text("Base px")
                                Spacer()
                                Text("\(selectedBase!)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if mode == .singleWidth {
                        HStack {
                            Text("Max width")
                            Spacer()
                            TextField("1024", text: $width)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else if mode == .box {
                        HStack {
                            Text("Max width")
                            Spacer()
                            TextField("1024", text: $width)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Max height (0 = unused)")
                            Spacer()
                            TextField("0", text: $height)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Toggle("Never upscale", isOn: $neverUpscale)
                    Toggle("Preserve aspect ratio", isOn: $preserveAspect)
                }
                .padding(8)
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Format", selection: $outFormat) {
                        ForEach(OutputFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)

                    if outFormat == .jpg {
                        HStack {
                            Text("JPEG Quality")
                            Slider(value: $jpegQuality, in: 50...100, step: 1)
                            Text("\(Int(jpegQuality))")
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                        }
                    }

                    if mode != .triple {
                        Toggle("Keep original filename", isOn: $keepOriginalName)
                    }

                    Picker("Destination", selection: $outputDestination) {
                        ForEach(OutputDestination.allCases) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    .pickerStyle(.menu)

                    if outputDestination == .chooseFolder {
                        HStack {
                            Text(customOutputDir?.lastPathComponent ?? "No folder selected")
                                .foregroundStyle(customOutputDir == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Browse…") { chooseOutputFolder() }
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Post-processing") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Strip metadata", isOn: $stripMetadata)
                    Toggle("Send to ImageOptim", isOn: $sendToImageOptim)
                }
                .padding(8)
            }

            Spacer()
        }
        .frame(width: 380)
    }

    private var fileList: some View {
        GroupBox("Images (\(model.files.count))") {
            VStack(spacing: 10) {
                ZStack {
                    if model.files.isEmpty {
                        VStack(spacing: 8) {
                            Text("Drag & drop images or folders here")
                                .foregroundStyle(.secondary)
                            Text("or use “Choose Images…” (⌘O)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        List(selection: $fileSelection) {
                            ForEach(model.files, id: \.self) { url in
                                HStack(spacing: 8) {
                                    if let nsImage = NSImage(contentsOf: url) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Image(systemName: "photo")
                                            .frame(width: 32, height: 32)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .onDelete { idx in
                                model.files.remove(atOffsets: idx)
                            }
                            .onMove { source, destination in
                                model.files.move(fromOffsets: source, toOffset: destination)
                            }
                        }
                        .onDeleteCommand {
                            model.files.removeAll { fileSelection.contains($0) }
                            fileSelection.removeAll()
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers)
                }

                GroupBox("Log") {
                    ScrollView {
                        Text(log.isEmpty ? "Ready." : log)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 140)
                }
            }
            .padding(8)
        }
    }

    private var footer: some View {
        HStack {
            Button(isRunning ? "Processing…" : "Process") { process() }
                .keyboardShortcut(.defaultAction)
                .disabled(model.files.isEmpty || isRunning)

            if isRunning {
                Button("Cancel") { isCancelled = true }
                    .keyboardShortcut(.cancelAction)
            }

            if !lastOutputURLs.isEmpty && !isRunning {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(lastOutputURLs)
                }
            }

            Spacer()

            if isRunning && totalCount > 0 {
                Text("\(processedCount)/\(totalCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(processedCount), total: Double(totalCount))
                    .frame(width: 120)
            }
        }
    }

    // MARK: - File picking / drop

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .png, .jpeg, .tiff, .bmp, .gif, .heic, .folder,
            UTType(filenameExtension: "webp") ?? .image,
            UTType(filenameExtension: "avif") ?? .image,
        ]
        if panel.runModal() == .OK {
            model.addFiles(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for p in providers {
            _ = p.loadObject(ofClass: NSURL.self) { obj, _ in
                guard let nsurl = obj as? NSURL else { return }
                let url = nsurl as URL
                DispatchQueue.main.async {
                    model.addFiles([url])
                }
            }
        }
        return true
    }
    
    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            customOutputDir = url
            if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "customOutputDirBookmark")
            }
        }
    }

    // MARK: - Processing

    private func process() {
        let inputs = model.files

        if outputDestination == .chooseFolder {
            if customOutputDir == nil {
                chooseOutputFolder()
            }
            guard customOutputDir != nil else { return }
        }

        // Validate
        func int(_ s: String) -> Int? { Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        func mustPos(_ s: String, _ name: String) -> Int {
            guard let v = int(s), v > 0 else { fatalUser("\(name) must be a positive integer."); return 1 }
            return v
        }
        func intOrZero(_ s: String, _ name: String) -> Int {
            guard let v = int(s), v >= 0 else { fatalUser("\(name) must be 0 or a positive integer."); return 0 }
            return v
        }

        var base = 0
        var maxW = 0
        var maxH = 0

        switch mode {
        case .triple:
            if let b = selectedBase { base = b }
            else { base = mustPos(customBase, "Base px") }
        case .singleWidth:
            maxW = mustPos(width, "Max width")
        case .box:
            maxW = intOrZero(width, "Max width")
            maxH = intOrZero(height, "Max height")
            if maxW == 0 && maxH == 0 { fatalUser("Box mode needs a max width or max height."); return }
        }

        // Check for files that would be overwritten
        let conflicts = collectOutputURLs(inputs: inputs, mode: mode, base: base, maxW: maxW, maxH: maxH, destination: outputDestination, customDir: customOutputDir)
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        if !conflicts.isEmpty {
            let inputSet = Set(inputs)
            let overwritesOriginals = !conflicts.filter { inputSet.contains($0) }.isEmpty

            let alert = NSAlert()
            alert.alertStyle = overwritesOriginals ? .critical : .warning
            alert.messageText = overwritesOriginals
                ? "This will overwrite \(conflicts.count) original source file\(conflicts.count == 1 ? "" : "s")"
                : "\(conflicts.count) file\(conflicts.count == 1 ? "" : "s") will be overwritten"
            let fileList = conflicts.prefix(10).map { $0.lastPathComponent }.joined(separator: "\n")
            alert.informativeText = fileList + (conflicts.count > 10 ? "\n...and \(conflicts.count - 10) more" : "")
            alert.addButton(withTitle: "Overwrite")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }

        isRunning = true
        isCancelled = false
        log = ""
        processedCount = 0
        totalCount = inputs.count

        DispatchQueue.global(qos: .userInitiated).async {
            let (results, outputFiles) = runBatch(inputs: inputs, mode: mode, base: base, maxW: maxW, maxH: maxH, destination: self.outputDestination, customDir: self.customOutputDir)
            DispatchQueue.main.async {
                self.isRunning = false
                self.log = results
                self.lastOutputURLs = outputFiles
                self.model.files.removeAll()
                NSSound(named: "Glass")?.play()
                if self.sendToImageOptim && !outputFiles.isEmpty {
                    self.openInImageOptim(outputFiles)
                }
            }
        }
    }

    private func collectOutputURLs(inputs: [URL], mode: ScaleMode, base: Int, maxW: Int, maxH: Int, destination: OutputDestination, customDir: URL?) -> [URL] {
        var urls: [URL] = []
        for input in inputs {
            let dir = input.deletingLastPathComponent()
            let name = input.deletingPathExtension().lastPathComponent

            let outDir: URL = {
                switch destination {
                case .inPlace: return dir
                case .chooseFolder: return customDir!
                case .subfolder:
                    switch mode {
                    case .triple: return dir.appendingPathComponent("scaled", isDirectory: true)
                    case .singleWidth, .box: return dir.appendingPathComponent("scaled_single", isDirectory: true)
                    }
                }
            }()

            switch mode {
            case .triple:
                let s1 = base
                for (outName, _) in [("\(name)_\(s1)", s1), ("\(name)@2x", base * 2), ("\(name)@3x", base * 3)] {
                    urls.append(outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)"))
                }
            case .singleWidth:
                let outName = keepOriginalName ? name : "\(name)_w\(maxW)"
                urls.append(outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)"))
            case .box:
                let outName = keepOriginalName ? name : "\(name)_box\(maxW)x\(maxH)"
                urls.append(outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)"))
            }
        }
        return urls
    }

    private func fatalUser(_ message: String) {
        log.append("ERROR: \(message)\n")
        let alert = NSAlert()
        alert.messageText = "Invalid Settings"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func openInImageOptim(_ files: [URL]) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.pornel.ImageOptim") else {
            log += "\nImageOptim not found. Install it from https://imageoptim.com\n"
            return
        }
        NSWorkspace.shared.open(files, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func runBatch(inputs: [URL], mode: ScaleMode, base: Int, maxW: Int, maxH: Int, destination: OutputDestination, customDir: URL?) -> (String, [URL]) {
        var out = ""
        var outputFiles: [URL] = []
        var errorCount = 0

        for input in inputs {
            if isCancelled {
                out += "Cancelled.\n"
                break
            }

            guard FileManager.default.fileExists(atPath: input.path) else { continue }
            let dir = input.deletingLastPathComponent()
            let name = input.deletingPathExtension().lastPathComponent

            let outDir: URL = {
                switch destination {
                case .inPlace:
                    return dir
                case .chooseFolder:
                    return customDir!
                case .subfolder:
                    switch mode {
                    case .triple: return dir.appendingPathComponent("scaled", isDirectory: true)
                    case .singleWidth, .box: return dir.appendingPathComponent("scaled_single", isDirectory: true)
                    }
                }
            }()

            do {
                try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            } catch {
                out += "Failed to create output dir: \(outDir.path)\n"
                errorCount += 1
                continue
            }

            let inputDims = imagePixelSize(input)
            let countBefore = outputFiles.count

            switch mode {
            case .triple:
                let s1 = base
                let s2 = base * 2
                let s3 = base * 3

                for (outName, target) in [("\(name)_\(s1)", s1), ("\(name)@2x", s2), ("\(name)@3x", s3)] {
                    let (log, url) = processOne(input: input, outDir: outDir, outName: outName, target: target, inputDims: inputDims)
                    out += log
                    if let url { outputFiles.append(url) }
                }

            case .singleWidth:
                let outName = keepOriginalName ? name : "\(name)_w\(maxW)"
                let (log, url) = processOneFit(input: input, outDir: outDir, outName: outName, maxW: maxW, maxH: 0, inputDims: inputDims)
                out += log
                if let url { outputFiles.append(url) }

            case .box:
                let outName = keepOriginalName ? name : "\(name)_box\(maxW)x\(maxH)"
                let (log, url) = processOneFit(input: input, outDir: outDir, outName: outName, maxW: maxW, maxH: maxH, inputDims: inputDims)
                out += log
                if let url { outputFiles.append(url) }
            }

            if outputFiles.count == countBefore {
                errorCount += 1
            }

            DispatchQueue.main.async {
                self.processedCount += 1
            }
        }

        var summary = "Done. \(outputFiles.count) file\(outputFiles.count == 1 ? "" : "s") processed."
        if errorCount > 0 {
            summary += " \(errorCount) error\(errorCount == 1 ? "" : "s")."
        }
        out += summary
        return (out, outputFiles)
    }

    private func processOne(input: URL, outDir: URL, outName: String, target: Int, inputDims: (Int, Int)?) -> (String, URL?) {
        let outURL = outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)")

        if neverUpscale, let (w,h) = inputDims, w <= target, h <= target {
            return convertOnly(input: input, outURL: outURL, inputDims: inputDims)
        }

        let tmp = tmpURL(ext: input.pathExtension.isEmpty ? "tmp" : input.pathExtension)
        defer { try? FileManager.default.removeItem(at: tmp) }

        if preserveAspect {
            let r = run("/usr/bin/sips", ["-Z", "\(target)", input.path, "--out", tmp.path])
            if r.code != 0 { return ("sips resize failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
        } else {
            let r = run("/usr/bin/sips", ["-z", "\(target)", "\(target)", input.path, "--out", tmp.path])
            if r.code != 0 { return ("sips resize failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
        }

        return convertOnly(input: tmp, outURL: outURL, inputDims: inputDims)
    }

    private func processOneFit(input: URL, outDir: URL, outName: String, maxW: Int, maxH: Int, inputDims: (Int, Int)?) -> (String, URL?) {
        let outURL = outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)")

        if neverUpscale, let (w,h) = inputDims {
            let withinW = (maxW == 0) || (w <= maxW)
            let withinH = (maxH == 0) || (h <= maxH)
            if withinW && withinH {
                return convertOnly(input: input, outURL: outURL, inputDims: inputDims)
            }
        }

        let tmp = tmpURL(ext: input.pathExtension.isEmpty ? "tmp" : input.pathExtension)
        defer { try? FileManager.default.removeItem(at: tmp) }

        if preserveAspect {
            if maxW > 0 && maxH > 0, let (w,h) = inputDims {
                if w * maxH > h * maxW {
                    let r = run("/usr/bin/sips", ["--resampleWidth", "\(maxW)", input.path, "--out", tmp.path])
                    if r.code != 0 { return ("sips resampleWidth failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
                } else {
                    let r = run("/usr/bin/sips", ["--resampleHeight", "\(maxH)", input.path, "--out", tmp.path])
                    if r.code != 0 { return ("sips resampleHeight failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
                }
            } else if maxW > 0 {
                let r = run("/usr/bin/sips", ["--resampleWidth", "\(maxW)", input.path, "--out", tmp.path])
                if r.code != 0 { return ("sips resampleWidth failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
            } else {
                let r = run("/usr/bin/sips", ["--resampleHeight", "\(maxH)", input.path, "--out", tmp.path])
                if r.code != 0 { return ("sips resampleHeight failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
            }
        } else {
            if maxW > 0 && maxH > 0 {
                let r = run("/usr/bin/sips", ["-z", "\(maxH)", "\(maxW)", input.path, "--out", tmp.path])
                if r.code != 0 { return ("sips -z failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
            } else if maxW > 0 {
                let r = run("/usr/bin/sips", ["--resampleWidth", "\(maxW)", input.path, "--out", tmp.path])
                if r.code != 0 { return ("sips resampleWidth failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
            } else {
                let r = run("/usr/bin/sips", ["--resampleHeight", "\(maxH)", input.path, "--out", tmp.path])
                if r.code != 0 { return ("sips resampleHeight failed: \(input.lastPathComponent)\n\(r.err)\n", nil) }
            }
        }

        return convertOnly(input: tmp, outURL: outURL, inputDims: inputDims)
    }

    private func convertOnly(input: URL, outURL: URL, inputDims: (Int, Int)? = nil) -> (String, URL?) {
        var args: [String] = ["-s", "format", outFormat.sipsFormat]
        if outFormat == .jpg {
            args += ["-s", "formatOptions", "\(Int(jpegQuality))"]
        }
        args += [input.path, "--out", outURL.path]

        let r = run("/usr/bin/sips", args)
        if r.code != 0 {
            return ("convert failed: \(input.lastPathComponent)\n\(r.err)\n", nil)
        }

        if stripMetadata {
            stripMetadataFromFile(outURL)
        }

        let outDims = imagePixelSize(outURL)
        let dimsStr: String
        if let (iw, ih) = inputDims, let (ow, oh) = outDims {
            dimsStr = " (\(iw)x\(ih) -> \(ow)x\(oh))"
        } else if let (ow, oh) = outDims {
            dimsStr = " (\(ow)x\(oh))"
        } else {
            dimsStr = ""
        }

        return ("OK: \(outURL.lastPathComponent)\(dimsStr)\n", outURL)
    }

    private func stripMetadataFromFile(_ url: URL) {
        let properties = ["make", "model", "software", "description", "copyright", "artist", "creation"]
        for prop in properties {
            _ = run("/usr/bin/sips", ["-d", prop, url.path])
        }
        _ = run("/usr/bin/sips", ["--deleteColorManagementProperties", url.path])
    }

    private func imagePixelSize(_ url: URL) -> (Int, Int)? {
        let rW = run("/usr/bin/sips", ["-g", "pixelWidth", url.path])
        let rH = run("/usr/bin/sips", ["-g", "pixelHeight", url.path])
        guard rW.code == 0, rH.code == 0 else { return nil }

        func parse(_ s: String) -> Int? {
            return s.split(whereSeparator: \.isNewline)
                .first(where: { $0.contains("pixelWidth") || $0.contains("pixelHeight") })
                .flatMap { line in
                    line.split(separator: ":").last.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                }
        }
        guard let w = parse(rW.out), let h = parse(rH.out) else { return nil }
        return (w, h)
    }

    private func tmpURL(ext: String) -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let name = UUID().uuidString
        return dir.appendingPathComponent("\(name).\(ext)")
    }

    private func run(_ launchPath: String, _ args: [String]) -> (code: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return (1, "", "Failed to run: \(launchPath) \(args.joined(separator: " "))\n\(error)")
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        return (p.terminationStatus, outStr, errStr)
    }
}

// MARK: - Preset Editor

struct PresetEditorView: View {
    @ObservedObject var store: PresetStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    @State private var newBase: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Presets")
                .font(.headline)
                .padding()

            List {
                ForEach(store.presets) { preset in
                    HStack {
                        Text(store.label(for: preset))
                        Spacer()
                        Button(role: .destructive) {
                            store.presets.removeAll { $0.id == preset.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { source, destination in
                    store.presets.move(fromOffsets: source, toOffset: destination)
                }
            }

            Divider()

            HStack {
                TextField("Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                TextField("Base px", text: $newBase)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Button("Add") {
                    guard let base = Int(newBase.trimmingCharacters(in: .whitespaces)), base > 0 else { return }
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.presets.append(SavedPreset(name: name, base: base))
                    newName = ""
                    newBase = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || Int(newBase) == nil)
            }
            .padding()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(width: 450, height: 380)
    }
}
