//
//  ContentView.swift
//  Image Scaler
//
//  Created by Christian Kittle on 2/9/26.
//

import SwiftUI
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
    var id: String { rawValue }

    var sipsFormat: String {
        switch self {
        case .jpg: return "jpeg"
        case .png: return "png"
        }
    }

    var fileExt: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        }
    }
}

struct Preset: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let base: Int?
}

private let presets: [Preset] = [
    .init(title: "Tab Bar Item (30px base → 30/60/90)", base: 30),
    .init(title: "Tab Bar Item (25px base → 25/50/75)", base: 25),
    .init(title: "Custom Table/List Icon (48px base → 48/96/144)", base: 48),
    .init(title: "Small Button/Icon (20px base → 20/40/60)", base: 20),
    .init(title: "Navigation Bar/Toolbar Glyph (24px base → 24/48/72)", base: 24),
    .init(title: "Large Icon (64px base → 64/128/192)", base: 64),
    .init(title: "Custom…", base: nil),
]

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    @AppStorage("scaleMode") private var mode: ScaleMode = .singleWidth
    @AppStorage("presetIndex") private var presetIndex: Int = 2
    @AppStorage("customBase") private var customBase: String = "48"

    @AppStorage("maxWidth") private var width: String = "1024"
    @AppStorage("maxHeight") private var height: String = "0"

    @AppStorage("neverUpscale") private var neverUpscale: Bool = true
    @AppStorage("preserveAspect") private var preserveAspect: Bool = true
    @AppStorage("outputFormat") private var outFormat: OutputFormat = .jpg

    @AppStorage("keepOriginalName") private var keepOriginalName: Bool = false
    @AppStorage("sendToImageOptim") private var sendToImageOptim: Bool = false

    private var preset: Preset { presets[min(presetIndex, presets.count - 1)] }

    @State private var isRunning = false
    @State private var log: String = ""

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
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Mode", selection: $mode) {
                        ForEach(ScaleMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    if mode == .triple {
                        Picker("UI Preset", selection: $presetIndex) {
                            ForEach(presets.indices, id: \.self) { i in
                                Text(presets[i].title).tag(i)
                            }
                        }
                        .pickerStyle(.menu)

                        if preset.base == nil {
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
                                Text("\(preset.base!)")
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

                    Divider().padding(.vertical, 4)

                    Toggle("Never upscale", isOn: $neverUpscale)
                    Toggle("Preserve aspect ratio", isOn: $preserveAspect)

                    Picker("Format", selection: $outFormat) {
                        ForEach(OutputFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode != .triple {
                        Toggle("Keep original filename", isOn: $keepOriginalName)
                    }
                    Toggle("Send to ImageOptim", isOn: $sendToImageOptim)

                    Text("Output folders: UI Assets → scaled, Single → scaled_single")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        Text("Drag & drop images here")
                            .foregroundStyle(.secondary)
                        Text("or use “Choose Images…”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 120)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers)
                }

                List {
                    ForEach(model.files, id: \.self) { url in
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .onDelete { idx in
                        model.files.remove(atOffsets: idx)
                    }
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

            Spacer()

            if isRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - File picking / drop

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .png, .jpeg, .tiff, .bmp, .gif, UTType(filenameExtension: "webp") ?? .image
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
    
    // MARK: - Processing

    private func process() {
        let inputs = model.files

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
            if let b = preset.base { base = b }
            else { base = mustPos(customBase, "Base px") }
        case .singleWidth:
            maxW = mustPos(width, "Max width")
        case .box:
            maxW = intOrZero(width, "Max width")
            maxH = intOrZero(height, "Max height")
            if maxW == 0 && maxH == 0 { fatalUser("Box mode needs a max width or max height."); return }
        }

        isRunning = true
        log = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let (results, outputFiles) = runBatch(inputs: inputs, mode: mode, base: base, maxW: maxW, maxH: maxH)
            DispatchQueue.main.async {
                self.isRunning = false
                self.log = results
                self.model.files.removeAll()
                if self.sendToImageOptim && !outputFiles.isEmpty {
                    self.openInImageOptim(outputFiles)
                }
            }
        }
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

    private func runBatch(inputs: [URL], mode: ScaleMode, base: Int, maxW: Int, maxH: Int) -> (String, [URL]) {
        var out = ""
        var outputFiles: [URL] = []

        for input in inputs {
            guard FileManager.default.fileExists(atPath: input.path) else { continue }
            let dir = input.deletingLastPathComponent()
            let name = input.deletingPathExtension().lastPathComponent

            let outDir: URL = {
                switch mode {
                case .triple: return dir.appendingPathComponent("scaled", isDirectory: true)
                case .singleWidth, .box: return dir.appendingPathComponent("scaled_single", isDirectory: true)
                }
            }()

            do {
                try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            } catch {
                out += "Failed to create output dir: \(outDir.path)\n"
                continue
            }

            switch mode {
            case .triple:
                let s1 = base
                let s2 = base * 2
                let s3 = base * 3

                for (outName, target) in [("\(name)_\(s1)", s1), ("\(name)@2x", s2), ("\(name)@3x", s3)] {
                    let (log, url) = processOne(input: input, outDir: outDir, outName: outName, target: target)
                    out += log
                    if let url { outputFiles.append(url) }
                }

            case .singleWidth:
                let outName = keepOriginalName ? name : "\(name)_w\(maxW)"
                let (log, url) = processOneFit(input: input, outDir: outDir, outName: outName, maxW: maxW, maxH: 0)
                out += log
                if let url { outputFiles.append(url) }

            case .box:
                let outName = keepOriginalName ? name : "\(name)_box\(maxW)x\(maxH)"
                let (log, url) = processOneFit(input: input, outDir: outDir, outName: outName, maxW: maxW, maxH: maxH)
                out += log
                if let url { outputFiles.append(url) }
            }
        }

        return (out.isEmpty ? "Done." : out, outputFiles)
    }

    private func processOne(input: URL, outDir: URL, outName: String, target: Int) -> (String, URL?) {
        let outURL = outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)")

        if neverUpscale, let (w,h) = imagePixelSize(input), w <= target, h <= target {
            return convertOnly(input: input, outURL: outURL)
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

        return convertOnly(input: tmp, outURL: outURL)
    }

    private func processOneFit(input: URL, outDir: URL, outName: String, maxW: Int, maxH: Int) -> (String, URL?) {
        let outURL = outDir.appendingPathComponent("\(outName).\(outFormat.fileExt)")

        if neverUpscale, let (w,h) = imagePixelSize(input) {
            let withinW = (maxW == 0) || (w <= maxW)
            let withinH = (maxH == 0) || (h <= maxH)
            if withinW && withinH {
                return convertOnly(input: input, outURL: outURL)
            }
        }

        let tmp = tmpURL(ext: input.pathExtension.isEmpty ? "tmp" : input.pathExtension)
        defer { try? FileManager.default.removeItem(at: tmp) }

        if preserveAspect {
            if maxW > 0 && maxH > 0, let (w,h) = imagePixelSize(input) {
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

        return convertOnly(input: tmp, outURL: outURL)
    }

    private func convertOnly(input: URL, outURL: URL) -> (String, URL?) {
        let args: [String] = {
            switch outFormat {
            case .png:
                return ["-s", "format", outFormat.sipsFormat, input.path, "--out", outURL.path]
            case .jpg:
                return ["-s", "format", outFormat.sipsFormat, "-s", "formatOptions", "90", input.path, "--out", outURL.path]
            }
        }()

        let r = run("/usr/bin/sips", args)
        if r.code != 0 {
            return ("convert failed: \(input.lastPathComponent)\n\(r.err)\n", nil)
        }
        return ("OK: \(outURL.lastPathComponent)\n", outURL)
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
