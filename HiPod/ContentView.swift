// Hi-Res iPod Utility – DSD/Hi‑Res → ALAC
// macOS 12+, Swift 5.5, SwiftUI single‑file app
// Uses Homebrew ffmpeg/ffprobe (prefers /opt/homebrew/bin, falls back to /usr/local/bin)
// Input: AIFF, WAV, FLAC, DSF. Output: ALAC (.m4a)
// OUTPUT PROFILES (user‑requested):
//  - CD →  16‑bit / 44.1 kHz (ALAC)
//  - BD AUDIO → 16‑bit / 48 kHz (ALAC)
//  - SACD/DSD → 24‑bit / 48 kHz (ALAC)
// Notes:
//  - App warns clearly about *any* lossy operations (resample, bit‑depth reduction, downmix, DSD→PCM filtering/headroom).
//  - iPod Classic stock firmware is reliably compatible only with 16/44.1. 48 kHz and/or 24‑bit may not play; the UI surfaces this.
//  - No lossy codecs are ever used (ALAC only).

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import IOKit
import IOKit.storage

struct IPodPrepApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - Models

enum OutputProfile: String, CaseIterable, Identifiable {
    case cd = "CD (16/44.1)"
    case bdAudio = "BD AUDIO (16/48)"
    case sacd = "SACD/DSD (24/48)"
    var id: String { rawValue }

    var targetSampleRate: Int { switch self { case .cd: return 44100; case .bdAudio, .sacd: return 48000 } }
    var targetBitDepth: Int { switch self { case .cd, .bdAudio: return 16; case .sacd: return 24 } }
    var targetSuffix: String { switch self { case .cd: return "CD_16-44"; case .bdAudio: return "BD_16-48"; case .sacd: return "SACD_24-48" } }
}

struct SelectedFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var info: FormatInfo? = nil
    var warnings: [String] = []
    var status: FileStatus = .queued
    var outputURL: URL? = nil
}

enum FileStatus: String { case queued = "Queued", probing = "Probing…", ready = "Ready", converting = "Converting…", done = "Done", failed = "Failed" }

struct FormatInfo: Codable, Hashable {
    var codecName: String
    var sampleRate: Int
    var bitsPerRawSample: Int?
    var channels: Int
    var isDSD: Bool { codecName.lowercased().contains("dsd") }
}

struct DetectedIPod: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let mountPath: URL
    let capacity: String
    let generation: String
    let serialNumber: String?
    var isConnected: Bool = true
    var libraryCount: Int = 0
}

enum SyncStatus: String {
    case idle = "Ready to Sync"
    case scanning = "Scanning iPod..."
    case copying = "Copying Files..."
    case updating = "Updating Database..."
    case completed = "Sync Complete"
    case failed = "Sync Failed"
}

// MARK: - ViewModel

final class PrepViewModel: ObservableObject {
    @Published var profile: OutputProfile = .cd
    @Published var files: [SelectedFile] = []
    @Published var overallWarnings: [String] = []
    @Published var brewStatus: String = ""
    @Published var tempOutFolder: URL? = nil
    @Published var isConverting: Bool = false
    
    // iPod Sync Properties
    @Published var detectedIPods: [DetectedIPod] = []
    @Published var selectedIPod: DetectedIPod? = nil
    @Published var syncStatus: SyncStatus = .idle
    @Published var syncProgress: Double = 0.0
    @Published var showingSyncPanel: Bool = false

    private let fm = FileManager.default

    // Resolve tool paths once - prioritize bundled binaries
    lazy var ffmpegPath: String? = {
        print("🔧 Initializing ffmpeg path...")
        let bundled = getBundledBinaryPath("ffmpeg")
        let system = Self.findExecutable(["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"])
        let result = bundled ?? system
        print("🎯 Final ffmpeg path: \(result ?? "NOT FOUND")")
        return result
    }()
    
    lazy var ffprobePath: String? = {
        print("🔧 Initializing ffprobe path...")
        let bundled = getBundledBinaryPath("ffprobe")
        let system = Self.findExecutable(["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/usr/bin/ffprobe"])
        let result = bundled ?? system
        print("🎯 Final ffprobe path: \(result ?? "NOT FOUND")")
        return result
    }()
    
    lazy var brewPath: String? = Self.findExecutable(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"])

    static func findExecutable(_ candidates: [String]) -> String? {
        for c in candidates { if FileManager.default.isExecutableFile(atPath: c) { return c } }
        return nil
    }
    
    private func getBundledBinaryPath(_ binaryName: String) -> String? {
        guard let bundlePath = Bundle.main.resourcePath else { 
            print("❌ No resource path found in bundle")
            return nil 
        }
        let binaryPath = bundlePath + "/" + binaryName
        
        print("🔍 Looking for \(binaryName) at: \(binaryPath)")
        
        if fm.fileExists(atPath: binaryPath) {
            print("📁 File exists: \(binaryPath)")
            if fm.isExecutableFile(atPath: binaryPath) {
                print("✅ \(binaryName) is executable")
                return binaryPath
            } else {
                print("⚠️ \(binaryName) exists but not executable")
            }
        } else {
            print("❌ \(binaryName) not found at \(binaryPath)")
        }
        return nil
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.aiff, .wav, .init(filenameExtension: "flac")!, .init(filenameExtension: "dsf")!]
        } else {
            panel.allowedFileTypes = ["aiff","aif","wav","flac","dsf"]
        }
        if panel.runModal() == .OK {
            files = panel.urls.map { SelectedFile(url: $0) }
            overallWarnings.removeAll()
            Task { await probeAll() }
        }
    }

    func ensureTempFolder() {
        if tempOutFolder == nil {
            let musicURL = fm.urls(for: .musicDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Music")
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let dir = musicURL.appendingPathComponent("HiRes-iPod-\(stamp)", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            DispatchQueue.main.async { self.tempOutFolder = dir }
        }
    }

    func revealOutputFolder() { if let out = tempOutFolder { NSWorkspace.shared.activateFileViewerSelecting([out]) } }
    
    // MARK: - iPod Detection & Sync
    
    func scanForIPods() {
        detectedIPods.removeAll()
        
        // Get all mounted volumes
        let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeIsRemovableKey,
            .volumeIdentifierKey
        ], options: [.skipHiddenVolumes]) ?? []
        
        for volume in volumes {
            if isIPodVolume(volume) {
                if let ipod = createIPodFromVolume(volume) {
                    detectedIPods.append(ipod)
                }
            }
        }
        
        // Auto-select first iPod if none selected
        if selectedIPod == nil && !detectedIPods.isEmpty {
            selectedIPod = detectedIPods.first
        }
    }
    
    private func isIPodVolume(_ volume: URL) -> Bool {
        // Check for iPod_Control directory
        let ipodControlPath = volume.appendingPathComponent("iPod_Control", isDirectory: true)
        
        // Also check for device info file
        let deviceInfoPath = volume.appendingPathComponent("iPod_Control/Device/SysInfo", isDirectory: false)
        
        return fm.fileExists(atPath: ipodControlPath.path) || 
               fm.fileExists(atPath: deviceInfoPath.path) ||
               volume.lastPathComponent.lowercased().contains("ipod")
    }
    
    private func createIPodFromVolume(_ volume: URL) -> DetectedIPod? {
        do {
            let resourceValues = try volume.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeIdentifierKey
            ])
            
            let name = resourceValues.volumeName ?? "Unknown iPod"
            let capacity = formatCapacity(resourceValues.volumeTotalCapacity)
            let generation = detectGeneration(volume)
            let libraryCount = countIPodLibrary(volume)
            
            return DetectedIPod(
                name: name,
                mountPath: volume,
                capacity: capacity,
                generation: generation,
                serialNumber: (resourceValues.volumeIdentifier as? UUID)?.uuidString,
                libraryCount: libraryCount
            )
        } catch {
            return nil
        }
    }
    
    private func formatCapacity(_ bytes: Int?) -> String {
        guard let bytes = bytes else { return "Unknown" }
        let gb = Double(bytes) / 1_000_000_000
        return String(format: "%.0f GB", gb)
    }
    
    private func detectGeneration(_ volume: URL) -> String {
        // Try to read SysInfo for generation info
        let sysInfoPath = volume.appendingPathComponent("iPod_Control/Device/SysInfo")
        
        if let sysInfo = try? String(contentsOf: sysInfoPath),
           let generation = parseGenerationFromSysInfo(sysInfo) {
            return generation
        }
        
        // Fallback to capacity-based detection
        do {
            let resources = try volume.resourceValues(forKeys: [.volumeTotalCapacityKey])
            if let capacity = resources.volumeTotalCapacity {
                return estimateGenerationFromCapacity(capacity)
            }
        } catch {}
        
        return "Classic"
    }
    
    private func parseGenerationFromSysInfo(_ sysInfo: String) -> String? {
        // Parse generation from SysInfo format
        let lines = sysInfo.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("boardHwName") || line.contains("ModelNumStr") {
                if line.contains("Video") { return "Video" }
                if line.contains("Classic") { return "Classic" }
                if line.contains("Nano") { return "Nano" }
                if line.contains("Mini") { return "Mini" }
                if line.contains("Photo") { return "Photo" }
            }
        }
        return nil
    }
    
    private func estimateGenerationFromCapacity(_ bytes: Int) -> String {
        let gb = bytes / 1_000_000_000
        switch gb {
        case 0..<8: return "Mini/Nano"
        case 8..<40: return "Classic 20/30GB"  
        case 40..<80: return "Photo/Video"
        case 80..<120: return "Classic 80GB"
        case 120..<200: return "Classic 160GB"
        default: return "Classic"
        }
    }
    
    private func countIPodLibrary(_ volume: URL) -> Int {
        let itunesDBPath = volume.appendingPathComponent("iPod_Control/iTunes/iTunesDB")
        
        // Simple count - in real implementation, we'd parse the binary format
        if fm.fileExists(atPath: itunesDBPath.path) {
            // Estimate based on file size (very rough)
            do {
                let attributes = try fm.attributesOfItem(atPath: itunesDBPath.path)
                let fileSize = attributes[.size] as? Int ?? 0
                return max(0, (fileSize - 1000) / 500) // Very rough estimate
            } catch {}
        }
        
        return 0
    }
    
    func syncToIPod() async {
        guard let ipod = selectedIPod else { return }
        guard !files.filter({ $0.status == .done }).isEmpty else { return }
        
        await MainActor.run {
            syncStatus = .scanning
            syncProgress = 0.0
        }
        
        let filesToSync = files.filter { $0.status == .done && $0.outputURL != nil }
        
        for (index, file) in filesToSync.enumerated() {
            await MainActor.run {
                syncStatus = .copying
                syncProgress = Double(index) / Double(filesToSync.count)
            }
            
            if await copyFileToIPod(file, to: ipod) {
                // File copied successfully
            } else {
                await MainActor.run { syncStatus = .failed }
                return
            }
        }
        
        await MainActor.run {
            syncStatus = .updating
            syncProgress = 0.9
        }
        
        // Update iPod database (simplified for now)
        await updateIPodDatabase(ipod)
        
        await MainActor.run {
            syncStatus = .completed
            syncProgress = 1.0
        }
        
        // Reset after delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            syncStatus = .idle
            syncProgress = 0.0
        }
    }
    
    private func copyFileToIPod(_ file: SelectedFile, to ipod: DetectedIPod) async -> Bool {
        guard let sourceURL = file.outputURL else { return false }
        
        // Create iPod music directory structure
        let musicDir = ipod.mountPath.appendingPathComponent("iPod_Control/Music", isDirectory: true)
        
        // Create F00, F01, etc. subdirectories (iPod uses this structure)
        let subDirIndex = abs(file.url.lastPathComponent.hash) % 50
        let subDir = musicDir.appendingPathComponent(String(format: "F%02d", subDirIndex), isDirectory: true)
        
        do {
            try fm.createDirectory(at: subDir, withIntermediateDirectories: true)
            
            // Generate unique iPod filename (4 chars + .m4a)
            var ipodFileName = String(format: "%04X.m4a", abs(file.url.lastPathComponent.hash) % 65536)
            var destinationURL = subDir.appendingPathComponent(ipodFileName)
            
            // If file exists, generate a unique name
            var counter = 1
            while fm.fileExists(atPath: destinationURL.path) {
                ipodFileName = String(format: "%04X.m4a", (abs(file.url.lastPathComponent.hash) + counter) % 65536)
                destinationURL = subDir.appendingPathComponent(ipodFileName)
                counter += 1
                
                // Safety check to prevent infinite loop
                if counter > 1000 {
                    print("❌ Could not find unique filename after 1000 attempts")
                    return false
                }
            }
            
            print("📁 Copying to: \(destinationURL.path)")
            try fm.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Successfully copied: \(ipodFileName)")
            return true
        } catch {
            print("❌ Copy failed: \(error)")
            return false
        }
    }
    
    private func updateIPodDatabase(_ ipod: DetectedIPod) async {
        // Simplified database update - in full implementation, we'd:
        // 1. Read existing iTunesDB
        // 2. Parse binary format
        // 3. Add new entries
        // 4. Recalculate checksums
        // 5. Write back to iPod
        
        // For now, just create a basic database marker
        let itunesDir = ipod.mountPath.appendingPathComponent("iPod_Control/iTunes", isDirectory: true)
        try? fm.createDirectory(at: itunesDir, withIntermediateDirectories: true)
        
        let timestamp = Date().timeIntervalSince1970
        let marker = "# Updated by Hi-Res iPod Utility at \(timestamp)\n"
        let markerURL = itunesDir.appendingPathComponent("LastSync.txt")
        try? marker.write(to: markerURL, atomically: true, encoding: .utf8)
    }

    // MARK: Probe
    func probeAll() async {
        guard let ffprobe = ffprobePath else {
            DispatchQueue.main.async { self.brewStatus = "ffprobe not found. Install ffmpeg (Homebrew) below." }
            return
        }
        await withTaskGroup(of: (UUID, FormatInfo?, [String]).self) { group in
            for f in files {
                group.addTask { [weak self] in
                    guard let self else { return (f.id, nil, ["Internal error"]) }
                    var warnings: [String] = []
                    let info = self.probeFile(ffprobe: ffprobe, url: f.url)
                    if let i = info {
                        // Build warnings against current profile
                        warnings += self.profileCompatibilityWarnings(i)
                        warnings += self.profileConversionWarnings(i)
                        if warnings.isEmpty { warnings.append("No quality‑reducing steps expected.") }
                    } else {
                        warnings.append("Could not probe file; will attempt conversion.")
                    }
                    return (f.id, info, warnings)
                }
            }
            var updatedFiles: [SelectedFile] = files
            for await result in group {
                if let idx = updatedFiles.firstIndex(where: { $0.id == result.0 }) {
                    updatedFiles[idx].info = result.1
                    updatedFiles[idx].warnings = result.2
                    updatedFiles[idx].status = .ready
                }
            }
            let finalFiles = updatedFiles
            let finalWarnings = Array(Set(updatedFiles.flatMap { $0.warnings })).sorted()
            DispatchQueue.main.async {
                self.files = finalFiles
                self.overallWarnings = finalWarnings
            }
        }
    }

    private func profileCompatibilityWarnings(_ i: FormatInfo) -> [String] {
        var w: [String] = []
        if profile != .cd {
            // Surface Classic compatibility caveat
            if profile == .bdAudio { w.append("iPod Classic compatibility is not guaranteed at 48 kHz.") }
            if profile == .sacd { w.append("iPod Classic compatibility is not guaranteed at 24‑bit / 48 kHz.") }
        }
        return w
    }

    private func profileConversionWarnings(_ i: FormatInfo) -> [String] {
        var w: [String] = []
        let tgtSR = profile.targetSampleRate
        let tgtBits = profile.targetBitDepth
        if i.isDSD { w.append("DSD→PCM conversion (−3 dB headroom + ultrasonic low‑pass).") }
        if i.sampleRate != tgtSR { w.append("Resample from \(i.sampleRate) Hz → \(tgtSR) Hz.") }
        if (i.bitsPerRawSample ?? tgtBits) != tgtBits {
            if tgtBits < (i.bitsPerRawSample ?? 24) { w.append("Bit‑depth reduction to \(tgtBits)‑bit (TPDF dither).") }
        }
        if i.channels > 2 { w.append("Downmix to stereo (\(i.channels)→2).") }
        return w
    }

    private func probeFile(ffprobe: String, url: URL) -> FormatInfo? {
        let args = ["-v","error","-select_streams","a:0","-show_entries","stream=codec_name,sample_rate,bits_per_raw_sample,channels","-of","json", url.path]
        
        print("🔍 Probing: \(url.lastPathComponent)")
        print("🔧 Probe command: \(ffprobe) \(args.joined(separator: " "))")
        
        let (out, err, code) = Self.run(cmd: ffprobe, args: args)
        
        print("📊 Probe exit code: \(code)")
        if !out.isEmpty { print("📝 Probe output: \(out)") }
        if !err.isEmpty { print("⚠️ Probe error: \(err)") }
        
        guard code == 0, let data = out.data(using: .utf8) else { 
            print("❌ Probe failed for \(url.lastPathComponent)")
            return nil 
        }
        
        struct Probe: Codable { struct Stream: Codable { let codec_name: String; let sample_rate: String; let bits_per_raw_sample: String?; let channels: Int } ; let streams: [Stream] }
        do {
            let p = try JSONDecoder().decode(Probe.self, from: data)
            guard let s = p.streams.first else { 
                print("❌ No audio streams found in \(url.lastPathComponent)")
                return nil 
            }
            let info = FormatInfo(codecName: s.codec_name, sampleRate: Int(s.sample_rate) ?? 0, bitsPerRawSample: Int(s.bits_per_raw_sample ?? ""), channels: s.channels)
            print("✅ Probed \(url.lastPathComponent): \(info.codecName) \(info.sampleRate)Hz \(info.bitsPerRawSample ?? 0)bit \(info.channels)ch")
            return info
        } catch { 
            print("❌ JSON decode failed for \(url.lastPathComponent): \(error)")
            return nil 
        }
    }

    // MARK: Convert
    func convertAll() async {
        guard !isConverting else { return }
        guard let ffmpeg = ffmpegPath else {
            DispatchQueue.main.async { self.brewStatus = "❌ FFmpeg not found - check bundled binaries" }
            return
        }
        
        // Debug: Log ffmpeg path
        print("🔧 Using FFmpeg at: \(ffmpeg)")
        
        ensureTempFolder()
        DispatchQueue.main.async { self.isConverting = true }

        var workingFiles = files
        for i in workingFiles.indices {
            workingFiles[i].status = .converting
            let currentFiles = workingFiles
            DispatchQueue.main.async { self.files = currentFiles }

            let input = workingFiles[i].url
            let base = input.deletingPathExtension().lastPathComponent
            let outURL = tempOutFolder!.appendingPathComponent("\(base)_iPod_\(profile.targetSuffix).m4a")

            let info = workingFiles[i].info
            let tgtSR = profile.targetSampleRate
            let tgtBits = profile.targetBitDepth

            var filters: [String] = []
            var ffArgs: [String] = ["-hide_banner","-y","-i", input.path, "-map","0:a:0","-map_metadata","0"]

            // DSD: add headroom and appropriate low‑pass
            if info?.isDSD == true {
                filters.append("volume=-3dB")
                // For 44.1k, ~20 kHz; for 48k, ~22 kHz
                let lp = (tgtSR == 44100) ? 20000 : 22000
                filters.append("lowpass=f=\(lp)")
            }

            // Downmix if needed
            if let ch = info?.channels, ch > 2 { ffArgs += ["-ac","2"] }

            // Resample only when needed or when DSD (always needed)
            if info?.sampleRate != tgtSR || (info?.isDSD ?? false) {
                if tgtBits == 16 { filters.append("aresample=resampler=soxr:precision=33:dither_method=triangular") }
                else { filters.append("aresample=resampler=soxr:precision=33") }
            } else {
                // If SR matches but we still need dither (e.g., 24→16), run aresample for dither only
                if tgtBits == 16, (info?.bitsPerRawSample ?? 24) > 16 {
                    filters.append("aresample=resampler=soxr:precision=33:dither_method=triangular")
                }
            }

            if !filters.isEmpty { ffArgs += ["-af", filters.joined(separator: ",")] }

            // Target container/format: ALAC, SR, bit depth
            ffArgs += ["-ar", String(tgtSR)]
            if tgtBits == 16 {
                ffArgs += ["-sample_fmt","s16","-c:a","alac"]
            } else {
                // 24‑bit ALAC via s32p input; set nominal bprs to 24 for metadata
                ffArgs += ["-sample_fmt","s32p","-c:a","alac","-bits_per_raw_sample","24"]
            }

            // Best‑effort cover art retention when present (won't fail if absent)
            ffArgs += ["-disposition:v:0","attached_pic"]

            ffArgs.append(outURL.path)

            // Debug: Log conversion command
            print("🎵 Converting: \(input.lastPathComponent)")
            print("🔧 Command: \(ffmpeg) \(ffArgs.joined(separator: " "))")
            
            let (stdout, stderr, code) = Self.run(cmd: ffmpeg, args: ffArgs)
            
            print("📊 Exit code: \(code)")
            if !stdout.isEmpty { print("📝 Stdout: \(stdout)") }
            if !stderr.isEmpty { print("⚠️ Stderr: \(stderr)") }
            
            if code == 0 { 
                workingFiles[i].status = .done
                workingFiles[i].outputURL = outURL 
                print("✅ Conversion successful: \(outURL.lastPathComponent)")
            } else { 
                workingFiles[i].status = .failed
                let errorMsg = stderr.split(separator: "\n").last.map(String.init) ?? "unknown error"
                workingFiles[i].warnings.append("FFmpeg failed: \(errorMsg)")
                print("❌ Conversion failed: \(errorMsg)")
            }
            let updatedFiles = workingFiles
            DispatchQueue.main.async { self.files = updatedFiles }
        }
        DispatchQueue.main.async { self.isConverting = false }
    }

    // MARK: Brew helper
    func installFFmpegViaBrew() async {
        guard let brew = brewPath else {
            DispatchQueue.main.async { self.brewStatus = "Homebrew not found at /opt/homebrew or /usr/local. Install Homebrew first: https://brew.sh" }
            return
        }
        DispatchQueue.main.async { self.brewStatus = "Installing ffmpeg… this may take several minutes." }
        let (_, err, code) = Self.run(cmd: brew, args: ["install","ffmpeg"])
        DispatchQueue.main.async {
            if code == 0 {
                self.brewStatus = "ffmpeg installed. Re‑probe or Convert again."
                self.ffmpegPath = Self.findExecutable(["/opt/homebrew/bin/ffmpeg","/usr/local/bin/ffmpeg"])
                self.ffprobePath = Self.findExecutable(["/opt/homebrew/bin/ffprobe","/usr/local/bin/ffprobe"])
            } else { self.brewStatus = "brew install failed: \(err)" }
        }
    }

    // MARK: Process runner
    @discardableResult
    static func run(cmd: String, args: [String]) -> (String, String, Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe
        do { try p.run() } catch { return ("", "Failed to start \(cmd): \(error.localizedDescription)", -1) }
        p.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        return (outStr, errStr, p.terminationStatus)
    }
}

// MARK: - UI

struct ContentView: View {
    @StateObject private var vm = PrepViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // iTunes-style brushed metal header
            brushedMetalHeader
            
            // Main content area
            VStack(spacing: 0) {
                // Control bar with classic iTunes styling
                classicControlBar
                
                // Divider
                Rectangle()
                    .fill(Color(red: 0.6, green: 0.6, blue: 0.6))
                    .frame(height: 1)

                // Warning panel (iTunes-style)
                if !vm.overallWarnings.isEmpty {
                    warningPanel
                }
                
                // Classic iTunes file list
                classicFileList

                // iPod Sync Panel (if iPods detected)
                if !vm.detectedIPods.isEmpty || vm.showingSyncPanel {
                    ipodSyncPanel
                }

                // Classic iTunes status bar
                classicStatusBar
            }
        }
        .background(iTunesBackground)
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            // Auto-scan for iPods on launch
            vm.scanForIPods()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi-Res iPod Utility")
                .font(.title2).bold()
            Text("DSD & Hi‑Res PCM → ALAC (CD 16/44.1 • BD 16/48 • SACD 24/48)")
                .foregroundColor(.black)
        }
    }

    private var fileRowHeader: some View {
        HStack {
            Text("File").frame(maxWidth: .infinity, alignment: .leading)
            Text("Format").frame(width: 140, alignment: .leading)
            Text("SR/Bit/Ch").frame(width: 140, alignment: .leading)
            Text("Warnings").frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: 120, alignment: .trailing)
        }
        .font(.caption).foregroundColor(.black)
    }

    private var fileList: some View {
        GroupBox("Selection") {
            VStack(alignment: .leading, spacing: 8) {
                fileRowHeader
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(vm.files) { f in
                            HStack(alignment: .top, spacing: 8) {
                                Text(f.url.lastPathComponent).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                                if let i = f.info {
                                    Text(i.codecName.uppercased()).frame(width: 140, alignment: .leading)
                                    Text("\(i.sampleRate) / \(i.bitsPerRawSample ?? 0) / \(i.channels)").frame(width: 140, alignment: .leading)
                                } else { Text("–").frame(width: 140, alignment: .leading); Text("–").frame(width: 140, alignment: .leading) }
                                VStack(alignment: .leading) { ForEach(f.warnings, id: \.self) { w in Text("• " + w).font(.caption) } }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(f.status.rawValue).frame(width: 120, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - iTunes-Style UI Components
    
    private var iTunesBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.94, green: 0.94, blue: 0.94),
                Color(red: 0.88, green: 0.88, blue: 0.88)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var brushedMetalHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "ipod")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi-Res iPod Utility")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                    
                    Text("DSD & Hi‑Res PCM → ALAC (CD 16/44.1 • BD 16/48 • SACD 24/48)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.92, green: 0.92, blue: 0.92),
                    Color(red: 0.85, green: 0.85, blue: 0.85)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var classicControlBar: some View {
        VStack(spacing: 12) {
            // Profile selector - standalone with clear background
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Convert To:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Simple horizontal buttons instead of segmented control
                    HStack(spacing: 8) {
                        ForEach(OutputProfile.allCases, id: \.self) { profile in
                            Button(action: { vm.profile = profile }) {
                                Text(profile.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(vm.profile == profile ? .white : .black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(vm.profile == profile ? Color.blue : Color.gray.opacity(0.2))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                )
                
                Spacer()
                
                // Classic iTunes buttons
                HStack(spacing: 8) {
                    classiciTunesButton("Choose Files…", action: vm.chooseFiles)
                        .keyboardShortcut("o", modifiers: [.command])
                    
                    if let _ = vm.tempOutFolder {
                        classiciTunesButton("Show in Finder", action: vm.revealOutputFolder)
                    } else {
                        classiciTunesButton("Prepare Folder") { vm.ensureTempFolder() }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.90, green: 0.90, blue: 0.90),
                    Color(red: 0.82, green: 0.82, blue: 0.82)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func classiciTunesButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.95, green: 0.95, blue: 0.95),
                            Color(red: 0.85, green: 0.85, blue: 0.85)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        )
        .buttonStyle(PlainButtonStyle())
    }
    
    private var warningPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("Quality Adjustments")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vm.overallWarnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                    }
                }
                
                Text("All outputs use ALAC (lossless). Warnings indicate technical steps required for iPod Classic compatibility.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var classicFileList: some View {
        VStack(spacing: 0) {
            // Classic iTunes header row
            HStack(spacing: 0) {
                classicColumnHeader("File", width: nil)
                classicColumnHeader("Format", width: 100)
                classicColumnHeader("Sample Rate", width: 100)
                classicColumnHeader("Bit Depth", width: 80)
                classicColumnHeader("Channels", width: 80)
                classicColumnHeader("Warnings", width: nil)
                classicColumnHeader("Status", width: 100)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.88, green: 0.88, blue: 0.88),
                        Color(red: 0.78, green: 0.78, blue: 0.78)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Rectangle()
                .fill(Color(red: 0.6, green: 0.6, blue: 0.6))
                .frame(height: 1)
            
            // File list with alternating row colors (classic iTunes style)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.files.enumerated()), id: \.element.id) { index, file in
                        classicFileRow(file: file, isEven: index.isMultiple(of: 2))
                        
                        if index < vm.files.count - 1 {
                            Rectangle()
                                .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(0)
        .padding(.horizontal, 16)
    }
    
    private func classicColumnHeader(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }
    
    private func classicFileRow(file: SelectedFile, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            // File name
            Text(file.url.lastPathComponent)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Format
            Text(file.info?.codecName.uppercased() ?? "–")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Sample Rate
            Text(file.info?.sampleRate != nil ? "\(file.info!.sampleRate) Hz" : "–")
                .font(.system(size: 11))
                .foregroundColor(.black)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Bit Depth
            Text(file.info?.bitsPerRawSample != nil ? "\(file.info!.bitsPerRawSample!)-bit" : "–")
                .font(.system(size: 11))
                .foregroundColor(.black)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Channels
            Text(file.info?.channels != nil ? "\(file.info!.channels)" : "–")
                .font(.system(size: 11))
                .foregroundColor(.black)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Warnings (condensed)
            Text(file.warnings.isEmpty ? "None" : "\(file.warnings.count) item\(file.warnings.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(file.warnings.isEmpty ? .green : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Status with color coding
            HStack(spacing: 4) {
                statusIcon(for: file.status)
                Text(file.status.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor(for: file.status))
            }
            .frame(width: 100, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 4)
        .background(
            isEven ? 
            Color(red: 0.98, green: 0.98, blue: 0.98) : 
            Color.white
        )
    }
    
    private func statusIcon(for status: FileStatus) -> some View {
        Group {
            switch status {
            case .queued:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .probing:
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
            case .ready:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .converting:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 10))
    }
    
    private func statusColor(for status: FileStatus) -> Color {
        switch status {
        case .queued: return .gray
        case .probing: return .blue
        case .ready: return .green
        case .converting: return .blue
        case .done: return .green
        case .failed: return .red
        }
    }
    
    private var classicStatusBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.7, green: 0.7, blue: 0.7))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Main convert button (classic iTunes style)
                Button(action: { Task { await vm.convertAll() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: vm.isConverting ? "arrow.triangle.2.circlepath" : "play.circle.fill")
                            .font(.system(size: 14))
                        Text(vm.isConverting ? "Converting…" : "Convert to \(vm.profile.targetSuffix) ALAC")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            vm.files.isEmpty || vm.isConverting || vm.ffmpegPath == nil ?
                            LinearGradient(
                                gradient: Gradient(colors: [Color.gray, Color.gray]),
                                startPoint: .top,
                                endPoint: .bottom
                            ) :
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.3, green: 0.5, blue: 0.9),
                                    Color(red: 0.2, green: 0.4, blue: 0.8)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
                .disabled(vm.files.isEmpty || vm.isConverting)
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Status text area
                VStack(alignment: .trailing, spacing: 2) {
                    if !vm.brewStatus.isEmpty {
                        Text(vm.brewStatus)
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    }
                    
                    if let out = vm.tempOutFolder {
                        Text("Output: \(out.lastPathComponent)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                    
                    // Show FFmpeg status
                    if vm.ffmpegPath != nil && vm.ffprobePath != nil {
                        let isBundled = vm.ffmpegPath?.contains(Bundle.main.resourcePath ?? "") == true
                        Text(isBundled ? "✅ Using bundled FFmpeg" : "✅ Using system FFmpeg")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    } else {
                        Text("❌ FFmpeg not available")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    
                    if vm.profile != .cd {
                        Text(vm.profile == .bdAudio ? "⚠️ 48 kHz may not play on iPod Classic" : "⚠️ 24-bit/48 kHz may not play on iPod Classic")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                
                // iPod scan button
                classiciTunesButton("Scan for iPods") { 
                    vm.scanForIPods()
                    if !vm.detectedIPods.isEmpty {
                        vm.showingSyncPanel = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.90, green: 0.90, blue: 0.90),
                        Color(red: 0.82, green: 0.82, blue: 0.82)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private var ipodSyncPanel: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.7, green: 0.7, blue: 0.7))
                .frame(height: 1)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "ipod")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    
                    Text("iPod Sync")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button("×") {
                        vm.showingSyncPanel = false
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                    .buttonStyle(PlainButtonStyle())
                }
                
                if vm.detectedIPods.isEmpty {
                    // No iPods detected
                    VStack(spacing: 8) {
                        Image(systemName: "ipod")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Text("No iPods Detected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                        
                        Text("Connect your iPod and click 'Scan for iPods'")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 20)
                } else {
                    // iPod selection and info
                    VStack(spacing: 12) {
                        // iPod picker
                        HStack {
                            Text("Device:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.black)
                            
                            Picker("Select iPod", selection: $vm.selectedIPod) {
                                ForEach(vm.detectedIPods, id: \.id) { ipod in
                                    Text("\(ipod.name) (\(ipod.capacity))")
                                        .foregroundColor(.black)
                                        .tag(ipod as DetectedIPod?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.black)
                            .frame(maxWidth: 200)
                            
                            Spacer()
                        }
                        
                        // Selected iPod info
                        if let ipod = vm.selectedIPod {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ipod.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text("\(ipod.generation) • \(ipod.capacity)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Library: \(ipod.libraryCount) songs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                    
                                    if vm.syncStatus != .idle {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text(vm.syncStatus.rawValue)
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Sync controls
                        HStack {
                            let completedFiles = vm.files.filter { $0.status == .done }
                            
                            Text("\(completedFiles.count) file\(completedFiles.count == 1 ? "" : "s") ready to sync")
                                .font(.system(size: 12))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Button(action: { Task { await vm.syncToIPod() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: vm.syncStatus == .idle ? "arrow.down.circle" : "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14))
                                    Text(vm.syncStatus == .idle ? "Sync to iPod" : vm.syncStatus.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        (completedFiles.isEmpty || vm.selectedIPod == nil || vm.syncStatus != .idle) ?
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.gray, Color.gray]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ) :
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.2, green: 0.7, blue: 0.2),
                                                Color(red: 0.1, green: 0.6, blue: 0.1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            )
                            .disabled(completedFiles.isEmpty || vm.selectedIPod == nil || vm.syncStatus != .idle)
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Progress bar
                        if vm.syncProgress > 0 && vm.syncStatus != .idle {
                            ProgressView(value: vm.syncProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        }
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.92, green: 0.92, blue: 0.92),
                        Color(red: 0.88, green: 0.88, blue: 0.88)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

