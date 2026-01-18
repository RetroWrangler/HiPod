// Hi-Res iPod Utility – DSD/Hi‑Res → ALAC
// macOS 12+, Swift 5.5, SwiftUI single‑file app
// Uses Homebrew ffmpeg/ffprobe (prefers /opt/homebrew/bin, falls back to /usr/local/bin)
// Input: AIFF, WAV, FLAC, DSF, MKA. Output: ALAC (.m4a)
// OUTPUT PROFILES (user‑requested):
//  - CD →  16‑bit / 44.1 kHz (ALAC)
//  - BD AUDIO → 16‑bit / 48 kHz (ALAC)
//  - SACD/DSD → 24‑bit / 48 kHz (ALAC)
//  - VINYL/LP → 24‑bit / 44.1 kHz (ALAC) [Optional]
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
    case cd = "CD"
    case vinyl = "LP"
    case bdAudio = "BDA"
    case sacd = "SACD/DSD"
    var id: String { rawValue }

    // For iPod mode - shows full spec
    var fullDisplayName: String {
        switch self {
        case .cd: return "CD (16/44.1)"
        case .vinyl: return "LP (24/44.1)"
        case .bdAudio: return "BD AUDIO (16/48)"
        case .sacd: return "SACD/DSD (24/48)"
        }
    }
    
    // For ePod/aPlayer mode - just the name
    var simpleDisplayName: String {
        return rawValue
    }
    
    func displayName(for playerType: String) -> String {
        if playerType == "ipod" {
            return fullDisplayName
        } else {
            return simpleDisplayName
        }
    }

    var targetSampleRate: Int { 
        switch self { 
        case .cd, .vinyl: return 44100
        case .bdAudio, .sacd: return 48000
        }
    }
    
    var targetBitDepth: Int { 
        switch self { 
        case .cd, .bdAudio: return 16
        case .sacd, .vinyl: return 24
        }
    }
    
    var targetSuffix: String { 
        switch self { 
        case .cd: return "CD_16-44"
        case .vinyl: return "LP_24-44"
        case .bdAudio: return "BD_16-48"
        case .sacd: return "SACD_24-48"
        }
    }
}

struct SelectedFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var info: FormatInfo? = nil
    var warnings: [String] = []
    var status: FileStatus = .queued
    var outputURL: URL? = nil
    var audioStreams: [AudioStreamInfo] = []  // All detected audio streams
    var selectedStreamIndices: Set<Int> = []  // Which streams user wants to extract
}

enum FileStatus: String { case queued = "Queued", probing = "Probing…", ready = "Ready", converting = "Converting…", done = "Done", failed = "Failed" }

struct FormatInfo: Codable, Hashable {
    var codecName: String
    var sampleRate: Int
    var bitsPerRawSample: Int?
    var channels: Int
    var isDSD: Bool { codecName.lowercased().contains("dsd") }
}

struct AudioStreamInfo: Codable, Hashable, Identifiable {
    let id = UUID()
    let index: Int  // Stream index in the file
    let codecName: String
    let sampleRate: Int
    let bitsPerRawSample: Int?
    let channels: Int
    let channelLayout: String?
    var isDSD: Bool { codecName.lowercased().contains("dsd") }
    
    var displayName: String {
        let codec = codecName.uppercased()
        let layout = channelLayout?.uppercased() ?? "\(channels)ch"
        return "\(codec) \(layout)"
    }
    
    // Custom coding keys to exclude the computed id
    enum CodingKeys: String, CodingKey {
        case index, codecName, sampleRate, bitsPerRawSample, channels, channelLayout
    }
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
    var playerType: PlayerType = .ipod
}

enum PlayerType: String, Codable {
    case ipod = "iPod"
    case epod = "ePod"
    case aplayer = "aPlayer (Android)"
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
    @Published var gainAdjustment: Double = 0.0  // dB adjustment, default 0
    
    // iPod Sync Properties
    @Published var detectedIPods: [DetectedIPod] = []
    @Published var selectedIPod: DetectedIPod? = nil
    @Published var syncStatus: SyncStatus = .idle
    @Published var syncProgress: Double = 0.0
    @Published var showingSyncPanel: Bool = false
    
    // Format Support Info
    @Published var showingFormatSupport: Bool = false
    
    // Player Type - using @AppStorage for automatic updates
    @AppStorage("playerType") var playerType: String = "ipod"
    
    // File Handling Settings
    @AppStorage("preserveOriginalFile") var preserveOriginalFile: Bool = false
    @AppStorage("pcmRequired") var pcmRequired: Bool = false
    @AppStorage("renameFiles") var renameFiles: Bool = true
    @AppStorage("addDiscIdentity") var addDiscIdentity: Bool = false
    
    // Disc Handling Settings
    @AppStorage("vinylSupport") var vinylSupport: Bool = false
    @AppStorage("cdSubType") var cdSubType: String = "CD"
    @AppStorage("sacdSubType") var sacdSubType: String = "SACD"
    @AppStorage("vinylSubType") var vinylSubType: String = "LP"
    @AppStorage("bdaSubType") var bdaSubType: String = "BDA"
    @AppStorage("convertToMatchDiscType") var convertToMatchDiscType: Bool = false
    
    // DSD Conversion Settings
    @AppStorage("dsd64TargetRate") var dsd64TargetRate: Int = 88200
    @AppStorage("dsd128TargetRate") var dsd128TargetRate: Int = 176400
    @AppStorage("dsd256TargetRate") var dsd256TargetRate: Int = 352800
    @AppStorage("dsd512TargetRate") var dsd512TargetRate: Int = 705600

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
            panel.allowedContentTypes = [.aiff, .wav, .init(filenameExtension: "flac")!, .init(filenameExtension: "dsf")!, .init(filenameExtension: "mka")!]
        } else {
            panel.allowedFileTypes = ["aiff","aif","wav","flac","dsf","mka"]
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
    
    // Helper function to determine DSD conversion target sample rate
    private func dsdConversionTargetRate(for sampleRate: Int) -> Int {
        // iPod mode always converts to 48 kHz
        if playerType == "ipod" {
            return 48000
        }
        
        // For aPlayer/DAP, use configured rates based on DSD type
        switch sampleRate {
        case 2822400:  // DSD64 (2.8224 MHz)
            return dsd64TargetRate
        case 5644800:  // DSD128 (5.6448 MHz)
            return dsd128TargetRate
        case 11289600: // DSD256 (11.2896 MHz)
            return dsd256TargetRate
        case 22579200: // DSD512 (22.5792 MHz)
            return dsd512TargetRate
        default:
            // Default fallback for unknown DSD rates
            return dsd64TargetRate
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
            let type = detectPlayerType(volume)
            
            switch playerType {
            case "ipod":
                if type == .ipod, let device = createIPodFromVolume(volume, type: type) {
                    detectedIPods.append(device)
                }
            case "aplayer":
                if type == .aplayer || (type == .epod && isAndroidDevice(volume)), let device = createIPodFromVolume(volume, type: .aplayer) {
                    detectedIPods.append(device)
                }
            case "epod":
                // ePod mode: detect all removable volumes
                if type == .epod || isRemovableVolume(volume), let device = createIPodFromVolume(volume, type: .epod) {
                    detectedIPods.append(device)
                }
            default:
                break
            }
        }
        
        // Auto-select first device if none selected
        if selectedIPod == nil && !detectedIPods.isEmpty {
            selectedIPod = detectedIPods.first
        }
    }
    
    private func detectPlayerType(_ volume: URL) -> PlayerType {
        // Check for iPod
        if isIPodVolume(volume) {
            return .ipod
        }
        
        // Check for Android (aPlayer) - look for Android folder structure
        if isAndroidDevice(volume) {
            return .aplayer
        }
        
        // Otherwise it's a generic ePod
        return .epod
    }
    
    private func isAndroidDevice(_ volume: URL) -> Bool {
        let androidPaths = [
            "Android/data",
            "Music",
            ".android_secure"
        ]
        
        for path in androidPaths {
            if fm.fileExists(atPath: volume.appendingPathComponent(path).path) {
                return true
            }
        }
        return false
    }
    
    private func isRemovableVolume(_ volume: URL) -> Bool {
        do {
            let resourceValues = try volume.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])
            return resourceValues.volumeIsRemovable == true || resourceValues.volumeIsEjectable == true
        } catch {
            return false
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
    
    private func createIPodFromVolume(_ volume: URL, type: PlayerType) -> DetectedIPod? {
        do {
            let resourceValues = try volume.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeIdentifierKey
            ])
            
            let name = resourceValues.volumeName ?? "Unknown Device"
            let capacity = formatCapacity(resourceValues.volumeTotalCapacity)
            
            let generation: String
            let libraryCount: Int
            
            switch type {
            case .ipod:
                generation = detectGeneration(volume)
                libraryCount = countIPodLibrary(volume)
            case .aplayer:
                generation = "Android Player"
                libraryCount = countMusicFiles(in: volume.appendingPathComponent("Music"))
            case .epod:
                generation = "ePod/Hi-Res DAP"
                libraryCount = countMusicFiles(in: volume)
            }
            
            return DetectedIPod(
                name: name,
                mountPath: volume,
                capacity: capacity,
                generation: generation,
                serialNumber: (resourceValues.volumeIdentifier as? UUID)?.uuidString,
                libraryCount: libraryCount,
                playerType: type
            )
        } catch {
            return nil
        }
    }
    
    private func countMusicFiles(in directory: URL) -> Int {
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        let musicExtensions = ["m4a", "mp3", "flac", "wav", "aiff", "aif"]
        var count = 0
        
        for case let fileURL as URL in enumerator {
            if musicExtensions.contains(fileURL.pathExtension.lowercased()) {
                count += 1
                if count > 1000 { break } // Limit for performance
            }
        }
        
        return count
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
            
            let success: Bool
            switch ipod.playerType {
            case .ipod:
                success = await copyFileToIPod(file, to: ipod)
            case .aplayer:
                success = await copyFileToAPlayer(file, to: ipod)
            case .epod:
                success = await copyFileToEPod(file, to: ipod)
            }
            
            if !success {
                await MainActor.run { syncStatus = .failed }
                return
            }
        }
        
        // Only update database for iPods
        if ipod.playerType == .ipod {
            await MainActor.run {
                syncStatus = .updating
                syncProgress = 0.9
            }
            await updateIPodDatabase(ipod)
        }
        
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
    
    private func copyFileToAPlayer(_ file: SelectedFile, to player: DetectedIPod) async -> Bool {
        guard let sourceURL = file.outputURL else { return false }
        
        // aPlayer: Copy to Music folder with organized structure
        let musicDir = player.mountPath.appendingPathComponent("Music", isDirectory: true)
        
        do {
            try fm.createDirectory(at: musicDir, withIntermediateDirectories: true)
            
            // Keep original filename for aPlayer
            let fileName = sourceURL.lastPathComponent
            let destinationURL = musicDir.appendingPathComponent(fileName)
            
            // If file exists, append number
            var finalDestination = destinationURL
            var counter = 1
            while fm.fileExists(atPath: finalDestination.path) {
                let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension
                finalDestination = musicDir.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                counter += 1
            }
            
            print("📁 Copying to aPlayer: \(finalDestination.path)")
            try fm.copyItem(at: sourceURL, to: finalDestination)
            print("✅ Successfully copied: \(finalDestination.lastPathComponent)")
            return true
        } catch {
            print("❌ Copy failed: \(error)")
            return false
        }
    }
    
    private func copyFileToEPod(_ file: SelectedFile, to player: DetectedIPod) async -> Bool {
        guard let sourceURL = file.outputURL else { return false }
        
        // ePod: Simple copy to root or Music folder
        var musicDir = player.mountPath.appendingPathComponent("Music", isDirectory: true)
        
        // If Music folder doesn't exist, just use root
        if !fm.fileExists(atPath: musicDir.path) {
            musicDir = player.mountPath
        } else {
            try? fm.createDirectory(at: musicDir, withIntermediateDirectories: true)
        }
        
        do {
            // Keep original filename
            let fileName = sourceURL.lastPathComponent
            var destinationURL = musicDir.appendingPathComponent(fileName)
            
            // If file exists, append number
            var counter = 1
            while fm.fileExists(atPath: destinationURL.path) {
                let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension
                destinationURL = musicDir.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                counter += 1
            }
            
            print("📁 Copying to ePod: \(destinationURL.path)")
            try fm.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Successfully copied: \(destinationURL.lastPathComponent)")
            return true
        } catch {
            print("❌ Copy failed: \(error)")
            return false
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
        
        // Only show iPod compatibility warnings in iPod mode
        if playerType == "ipod" && profile != .cd {
            // Surface Classic compatibility caveat
            if profile == .bdAudio { w.append("iPod Classic compatibility is not guaranteed at 48 kHz.") }
            if profile == .sacd { w.append("iPod Classic compatibility is not guaranteed at 24‑bit / 48 kHz.") }
        }
        
        // DSD128+ warning for ePod/aPlayer when not preserving originals
        if (playerType == "aplayer" || playerType == "epod") && !preserveOriginalFile && i.isDSD {
            // Check if it's DSD128 or higher (> 2.8MHz)
            if i.sampleRate > 2822400 {
                let dsdType = dsdTypeName(for: i.sampleRate)
                w.append("⚠️ \(dsdType) detected. Consider enabling 'Preserve Original Files' for best quality.")
            }
        }
        
        return w
    }
    
    private func dsdTypeName(for sampleRate: Int) -> String {
        switch sampleRate {
        case 0..<3_000_000: return "DSD64"
        case 3_000_000..<8_000_000: return "DSD128"
        case 8_000_000..<16_000_000: return "DSD256"
        default: return "DSD512"
        }
    }

    private func profileConversionWarnings(_ i: FormatInfo) -> [String] {
        var w: [String] = []
        
        let isNonIPod = playerType == "aplayer" || playerType == "epod"
        
        // Check if we're converting DSD
        let shouldConvertDSD = i.isDSD && (pcmRequired || playerType == "ipod")
        
        if shouldConvertDSD {
            let targetRate = dsdConversionTargetRate(for: i.sampleRate)
            let targetRateKhz = Double(targetRate) / 1000.0
            w.append("DSD→PCM conversion to 24-bit/\(String(format: "%.1f", targetRateKhz)) kHz (−3 dB headroom + ultrasonic low‑pass).")
        } else if i.isDSD && isNonIPod {
            // DSD will be preserved as DSD for ePod/aPlayer
            w.append("DSD file will be preserved in original format (DSF).")
        }
        
        // For non-DSD files in iPod mode, check for resampling/bit depth changes
        if !i.isDSD && playerType == "ipod" {
            let tgtSR = profile.targetSampleRate
            let tgtBits = profile.targetBitDepth
            
            if i.sampleRate != tgtSR { w.append("Resample from \(i.sampleRate) Hz → \(tgtSR) Hz.") }
            if (i.bitsPerRawSample ?? tgtBits) != tgtBits {
                if tgtBits < (i.bitsPerRawSample ?? 24) { w.append("Bit‑depth reduction to \(tgtBits)‑bit (TPDF dither).") }
            }
        } else if !i.isDSD && isNonIPod {
            // For ePod/aPlayer: convert to FLAC, preserve bit/sample rate
            w.append("Convert to FLAC, preserving \(i.bitsPerRawSample ?? 24)-bit/\(Double(i.sampleRate)/1000.0) kHz.")
        }
        
        if i.channels > 2 { w.append("Downmix to stereo (\(i.channels)→2).") }
        return w
    }

    // MARK: Get Album Metadata
    private func getAlbumName(ffprobe: String, url: URL) -> String? {
        let args = ["-v", "error", "-show_entries", "format_tags=album", "-of", "default=noprint_wrappers=1:nokey=1", url.path]
        
        let (out, _, code) = Self.run(cmd: ffprobe, args: args)
        
        if code == 0, !out.isEmpty {
            let albumName = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return albumName.isEmpty ? nil : albumName
        }
        return nil
    }
    
    private func probeFile(ffprobe: String, url: URL) -> FormatInfo? {
        let args = ["-v","error","-select_streams","a","-show_entries","stream=index,codec_name,sample_rate,bits_per_raw_sample,channels,channel_layout","-of","json", url.path]
        
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
        
        struct Probe: Codable { 
            struct Stream: Codable { 
                let index: Int
                let codec_name: String
                let sample_rate: String
                let bits_per_raw_sample: String?
                let channels: Int
                let channel_layout: String?
            }
            let streams: [Stream] 
        }
        
        do {
            let p = try JSONDecoder().decode(Probe.self, from: data)
            guard let s = p.streams.first else { 
                print("❌ No audio streams found in \(url.lastPathComponent)")
                return nil 
            }
            
            // Store all audio streams for multi-stream files
            let allStreams = p.streams.map { stream in
                AudioStreamInfo(
                    index: stream.index,
                    codecName: stream.codec_name,
                    sampleRate: Int(stream.sample_rate) ?? 0,
                    bitsPerRawSample: Int(stream.bits_per_raw_sample ?? ""),
                    channels: stream.channels,
                    channelLayout: stream.channel_layout
                )
            }
            
            // Update the file with all detected streams
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let idx = self.files.firstIndex(where: { $0.url == url }) {
                    self.files[idx].audioStreams = allStreams
                    // Auto-select first stream by default
                    if !allStreams.isEmpty {
                        self.files[idx].selectedStreamIndices = [0]
                    }
                }
            }
            
            let info = FormatInfo(
                codecName: s.codec_name,
                sampleRate: Int(s.sample_rate) ?? 0,
                bitsPerRawSample: Int(s.bits_per_raw_sample ?? ""),
                channels: s.channels
            )
            
            print("✅ Probed \(url.lastPathComponent): \(info.codecName) \(info.sampleRate)Hz \(info.bitsPerRawSample ?? 0)bit \(info.channels)ch (\(p.streams.count) stream\(p.streams.count == 1 ? "" : "s"))")
            return info
        } catch { 
            print("❌ JSON decode failed for \(url.lastPathComponent): \(error)")
            return nil 
        }
    }

    // MARK: Convert
    func convertAll() async {
        guard !isConverting else { return }
        
        ensureTempFolder()
        DispatchQueue.main.async { self.isConverting = true }
        
        // Check if we should preserve original files (for aPlayer/ePod only)
        let shouldPreserveOriginal = preserveOriginalFile && (playerType == "aplayer" || playerType == "epod")
        
        if shouldPreserveOriginal {
            // Simple copy mode - no conversion
            await copyOriginalFiles()
            DispatchQueue.main.async { self.isConverting = false }
            return
        }
        
        // Normal conversion mode
        guard let ffmpeg = ffmpegPath else {
            DispatchQueue.main.async { self.brewStatus = "❌ FFmpeg not found - check bundled binaries" }
            DispatchQueue.main.async { self.isConverting = false }
            return
        }
        
        print("🔧 Using FFmpeg at: \(ffmpeg)")

        // Group files by stream type for organized output numbering
        var streamTypeGroups: [String: [(fileIndex: Int, streamInfo: AudioStreamInfo)]] = [:]
        
        for (fileIndex, file) in files.enumerated() {
            let selectedStreams = file.selectedStreamIndices.sorted()
            for streamIdx in selectedStreams {
                if streamIdx < file.audioStreams.count {
                    let stream = file.audioStreams[streamIdx]
                    let streamType = stream.displayName
                    if streamTypeGroups[streamType] == nil {
                        streamTypeGroups[streamType] = []
                    }
                    streamTypeGroups[streamType]?.append((fileIndex, stream))
                }
            }
        }
        
        // Sort stream types for consistent ordering
        let sortedStreamTypes = streamTypeGroups.keys.sorted()
        var trackNumber = 1
        var workingFiles = files

        for streamType in sortedStreamTypes {
            guard let group = streamTypeGroups[streamType] else { continue }
            
            for (fileIndex, streamInfo) in group {
                workingFiles[fileIndex].status = .converting
                let currentFiles = workingFiles
                DispatchQueue.main.async { self.files = currentFiles }

                let input = workingFiles[fileIndex].url
                let base = input.deletingPathExtension().lastPathComponent
                
                let isNonIPod = playerType == "aplayer" || playerType == "epod"
                let shouldConvertDSD = streamInfo.isDSD && (pcmRequired || playerType == "ipod")
                
                // Determine output format and settings
                var tgtSR: Int
                var tgtBits: Int
                var outputCodec: String
                var fileExtension: String
                var suffix: String
                
                if streamInfo.isDSD && isNonIPod && !pcmRequired {
                    // For ePod/aPlayer: keep DSD as DSF (copy mode for this file)
                    let paddedTrackNum = String(format: "%02d", trackNumber)
                    let dsdType = dsdTypeName(for: streamInfo.sampleRate)
                    
                    let filename: String
                    if renameFiles {
                        filename = "\(paddedTrackNum) - \(base) - \(streamType)_\(dsdType).dsf"
                    } else {
                        filename = "\(base).dsf"
                    }
                    let outURL = tempOutFolder!.appendingPathComponent(filename)
                    
                    print("🎵 Preserving DSD: \(input.lastPathComponent) -> Track \(paddedTrackNum)")
                    
                    do {
                        try fm.copyItem(at: input, to: outURL)
                        workingFiles[fileIndex].status = .done
                        workingFiles[fileIndex].outputURL = outURL
                        print("✅ DSD copy successful: \(outURL.lastPathComponent)")
                    } catch {
                        workingFiles[fileIndex].status = .failed
                        workingFiles[fileIndex].warnings.append("DSD copy failed: \(error.localizedDescription)")
                        print("❌ DSD copy failed: \(error.localizedDescription)")
                    }
                    
                    let updatedFiles = workingFiles
                    DispatchQueue.main.async { self.files = updatedFiles }
                    trackNumber += 1
                    continue
                }
                
                if shouldConvertDSD {
                    // DSD to PCM conversion
                    tgtSR = dsdConversionTargetRate(for: streamInfo.sampleRate)
                    tgtBits = 24
                    suffix = "DSD-PCM_24-\(tgtSR/1000)"
                } else if isNonIPod {
                    // ePod/aPlayer: convert to FLAC, preserve bit/sample rate
                    tgtSR = streamInfo.sampleRate
                    tgtBits = streamInfo.bitsPerRawSample ?? 24
                    suffix = "FLAC_\(tgtBits)-\(tgtSR/1000)"
                    outputCodec = "flac"
                    fileExtension = "flac"
                } else {
                    // iPod: use profile settings for ALAC
                    tgtSR = profile.targetSampleRate
                    tgtBits = profile.targetBitDepth
                    suffix = profile.targetSuffix
                }
                
                // Set output format based on disc type matching (if enabled)
                if isNonIPod && convertToMatchDiscType {
                    switch profile {
                    case .cd:
                        outputCodec = "pcm_s16le"
                        fileExtension = "aif"
                        suffix = "CD_AIFF_\(tgtBits)-\(tgtSR/1000)"
                    case .bdAudio:
                        outputCodec = "flac"
                        fileExtension = "mka"
                        suffix = "BDA_MKA_\(tgtBits)-\(tgtSR/1000)"
                    case .sacd:
                        // SACD stays DSF (already handled above in DSD preservation)
                        outputCodec = "flac"
                        fileExtension = "flac"
                        suffix = "SACD_\(tgtBits)-\(tgtSR/1000)"
                    case .vinyl:
                        outputCodec = "flac"
                        fileExtension = "ogg"
                        suffix = "LP_OGG-FLAC_\(tgtBits)-\(tgtSR/1000)"
                    }
                } else if isNonIPod {
                    // Default ePod/aPlayer format
                    outputCodec = "flac"
                    fileExtension = "flac"
                } else {
                    // iPod mode
                    outputCodec = "alac"
                    fileExtension = "m4a"
                }
                
                let paddedTrackNum = String(format: "%02d", trackNumber)
                
                let filename: String
                if renameFiles {
                    filename = "\(paddedTrackNum) - \(base) - \(streamType)_\(suffix).\(fileExtension)"
                } else {
                    filename = "\(base).\(fileExtension)"
                }
                let outURL = tempOutFolder!.appendingPathComponent(filename)

                var filters: [String] = []
                var ffArgs: [String] = ["-hide_banner","-y","-i", input.path]
                
                // Map the specific stream
                ffArgs += ["-map", "0:a:\(streamInfo.index)", "-map_metadata", "0"]
                
                // Add disc identity to album name if enabled
                if addDiscIdentity, let ffprobe = ffprobePath {
                    if let originalAlbum = getAlbumName(ffprobe: ffprobe, url: input) {
                        let discIdentity: String
                        
                        // Map the profile to the user-selected disc sub-type
                        switch profile {
                        case .cd:
                            discIdentity = cdSubType
                        case .bdAudio:
                            discIdentity = bdaSubType
                        case .sacd:
                            discIdentity = sacdSubType
                        case .vinyl:
                            discIdentity = vinylSubType
                        }
                        
                        // Only add disc identity if it's not already present
                        let identityTag = "(\(discIdentity))"
                        let modifiedAlbum: String
                        
                        if originalAlbum.contains(identityTag) {
                            // Already has this disc identity, don't duplicate
                            modifiedAlbum = originalAlbum
                            print("🏷️ Album already has disc identity: \"\(originalAlbum)\"")
                        } else {
                            modifiedAlbum = "\(originalAlbum) \(identityTag)"
                            print("🏷️ Modified album tag: \"\(originalAlbum)\" → \"\(modifiedAlbum)\"")
                        }
                        
                        ffArgs += ["-metadata", "album=\(modifiedAlbum)"]
                    }
                }

                // DSD: add headroom and appropriate low‑pass (if converting to PCM)
                if shouldConvertDSD {
                    filters.append("volume=-3dB")
                    let lp = min(tgtSR / 2 - 2000, 22000)
                    filters.append("lowpass=f=\(lp)")
                }
                
                // Apply user gain adjustment (for all files)
                if gainAdjustment != 0.0 {
                    let gainStr = String(format: "%.1f", gainAdjustment)
                    filters.append("volume=\(gainStr)dB")
                }

                // Downmix if needed
                if streamInfo.channels > 2 { ffArgs += ["-ac","2"] }

                // Resample logic
                if playerType == "ipod" {
                    // iPod mode: resample if needed
                    if streamInfo.sampleRate != tgtSR || shouldConvertDSD {
                        if tgtBits == 16 { filters.append("aresample=resampler=soxr:precision=33:dither_method=triangular") }
                        else { filters.append("aresample=resampler=soxr:precision=33") }
                    } else if tgtBits == 16, (streamInfo.bitsPerRawSample ?? 24) > 16 {
                        filters.append("aresample=resampler=soxr:precision=33:dither_method=triangular")
                    }
                }
                // ePod/aPlayer: no resampling (preserve original rate)

                if !filters.isEmpty { ffArgs += ["-af", filters.joined(separator: ",")] }

                // Set output codec and format
                ffArgs += ["-ar", String(tgtSR)]
                
                if outputCodec == "flac" && fileExtension == "ogg" {
                    // OGG container with FLAC codec (for Vinyl profile)
                    ffArgs += ["-c:a", "flac"]
                    if tgtBits <= 16 {
                        ffArgs += ["-sample_fmt", "s16"]
                    } else {
                        ffArgs += ["-sample_fmt", "s32"]
                    }
                    ffArgs += ["-compression_level", "8"]  // Max FLAC compression
                    ffArgs += ["-f", "ogg"]  // Force OGG container format
                } else if outputCodec == "flac" {
                    // Standard FLAC output
                    ffArgs += ["-c:a", "flac"]
                    if tgtBits <= 16 {
                        ffArgs += ["-sample_fmt", "s16"]
                    } else {
                        ffArgs += ["-sample_fmt", "s32"]
                    }
                    ffArgs += ["-compression_level", "8"]  // Max FLAC compression
                } else if outputCodec == "pcm_s16le" {
                    // AIFF output (for CD profile)
                    ffArgs += ["-c:a", "pcm_s16le"]
                    ffArgs += ["-sample_fmt", "s16"]
                } else if fileExtension == "mka" {
                    // MKA container with FLAC (for BDA profile)
                    ffArgs += ["-c:a", "flac"]
                    if tgtBits <= 16 {
                        ffArgs += ["-sample_fmt", "s16"]
                    } else {
                        ffArgs += ["-sample_fmt", "s32"]
                    }
                    ffArgs += ["-compression_level", "8"]
                } else {
                    // ALAC output (iPod)
                    if tgtBits == 16 {
                        ffArgs += ["-sample_fmt","s16","-c:a","alac"]
                    } else {
                        ffArgs += ["-sample_fmt","s32p","-c:a","alac","-bits_per_raw_sample","24"]
                    }
                }

                // Cover art (FLAC, M4A, and MKA support it; OGG-FLAC also supports it)
                if fileExtension == "m4a" {
                    ffArgs += ["-disposition:v:0","attached_pic"]
                } else if fileExtension == "flac" || fileExtension == "mka" || fileExtension == "ogg" {
                    // FLAC, MKA, and OGG-FLAC support cover art
                    ffArgs += ["-map", "0:v?", "-c:v", "copy"]
                }

                ffArgs.append(outURL.path)

                print("🎵 Converting: \(input.lastPathComponent) [Stream \(streamInfo.index): \(streamType)] -> Track \(paddedTrackNum)")
                print("🔧 Command: \(ffmpeg) \(ffArgs.joined(separator: " "))")
                
                let (stdout, stderr, code) = Self.run(cmd: ffmpeg, args: ffArgs)
                
                print("📊 Exit code: \(code)")
                if !stdout.isEmpty { print("📝 Stdout: \(stdout)") }
                if !stderr.isEmpty { print("⚠️ Stderr: \(stderr)") }
                
                if code == 0 { 
                    workingFiles[fileIndex].status = .done
                    workingFiles[fileIndex].outputURL = outURL 
                    print("✅ Conversion successful: \(outURL.lastPathComponent)")
                } else { 
                    workingFiles[fileIndex].status = .failed
                    let errorMsg = stderr.split(separator: "\n").last.map(String.init) ?? "unknown error"
                    workingFiles[fileIndex].warnings.append("FFmpeg failed: \(errorMsg)")
                    print("❌ Conversion failed: \(errorMsg)")
                }
                
                let updatedFiles = workingFiles
                DispatchQueue.main.async { self.files = updatedFiles }
                
                trackNumber += 1
            }
        }
        
        DispatchQueue.main.async { self.isConverting = false }
    }
    
    // MARK: Copy Original Files (Preserve mode)
    private func copyOriginalFiles() async {
        print("📁 Preserve Original Files mode - copying without conversion")
        
        var workingFiles = files
        
        for (index, file) in files.enumerated() {
            workingFiles[index].status = .converting
            let currentFiles = workingFiles
            DispatchQueue.main.async { self.files = currentFiles }
            
            let input = file.url
            let fileName = input.lastPathComponent
            let outURL = tempOutFolder!.appendingPathComponent(fileName)
            
            print("📁 Copying: \(fileName)")
            
            do {
                // Check if file already exists
                var finalURL = outURL
                var counter = 1
                while fm.fileExists(atPath: finalURL.path) {
                    let nameWithoutExt = input.deletingPathExtension().lastPathComponent
                    let ext = input.pathExtension
                    finalURL = tempOutFolder!.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                    counter += 1
                }
                
                try fm.copyItem(at: input, to: finalURL)
                
                workingFiles[index].status = .done
                workingFiles[index].outputURL = finalURL
                print("✅ Copy successful: \(finalURL.lastPathComponent)")
            } catch {
                workingFiles[index].status = .failed
                workingFiles[index].warnings.append("Copy failed: \(error.localizedDescription)")
                print("❌ Copy failed: \(error.localizedDescription)")
            }
            
            let updatedFiles = workingFiles
            DispatchQueue.main.async { self.files = updatedFiles }
        }
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
    @AppStorage("useRetroUI") private var useRetroUI = false
    @AppStorage("forceAppearance") private var forceAppearance = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var scanButtonLabel: String {
        switch vm.playerType {
        case "ipod": return "Scan for iPods"
        case "epod": return "Scan for ePods"
        case "aplayer": return "Scan for aPlayers"
        default: return "Scan for Devices"
        }
    }
    
    private var syncButtonLabel: String {
        switch vm.playerType {
        case "ipod": return "Sync to iPod"
        case "epod": return "Sync to ePod"
        case "aplayer": return "Sync to aPlayer"
        default: return "Sync to Device"
        }
    }
    
    private var convertButtonLabel: String {
        let isPreserveMode = vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod")
        
        if vm.isConverting {
            return isPreserveMode ? "Copying…" : "Converting…"
        }
        
        if isPreserveMode {
            return "Copy Original Files"
        }
        
        let isNonIPod = vm.playerType == "aplayer" || vm.playerType == "epod"
        
        if isNonIPod && vm.convertToMatchDiscType {
            // Show format based on disc type
            switch vm.profile {
            case .cd:
                return "Convert to AIFF (CD)"
            case .bdAudio:
                return "Convert to MKA (BD Audio)"
            case .sacd:
                return "Convert to FLAC (SACD)"
            case .vinyl:
                return "Convert to OGG-FLAC (Vinyl)"
            }
        } else if isNonIPod {
            // Default ePod/aPlayer format
            return "Convert to FLAC"
        } else {
            // For iPod: show profile with bit/sample rate
            return "Convert to \(vm.profile.targetSuffix) ALAC"
        }
    }
    
    private var devicePickerLabel: String {
        return "Device:"
    }
    
    private var devicePickerAccessibilityLabel: String {
        switch vm.playerType {
        case "ipod": return "Select iPod"
        case "epod": return "Select Player"
        case "aplayer": return "Select Player"
        default: return "Select Device"
        }
    }
    
    private var syncPanelTitle: String {
        switch vm.playerType {
        case "ipod": return "iPod Sync"
        case "epod": return "ePod Sync"
        case "aplayer": return "aPlayer Sync"
        default: return "Device Sync"
        }
    }
    
    // Dynamic header subtitle based on player type and settings
    private var headerSubtitle: String {
        let isNonIPod = vm.playerType == "aplayer" || vm.playerType == "epod"
        let isPreserveMode = vm.preserveOriginalFile && isNonIPod
        
        if isPreserveMode {
            return "Preserving Original Files (No Conversion)"
        } else if isNonIPod {
            return "DSD & Hi‑Res PCM → FLAC (Preserves Source Bit/Sample Rate)"
        } else {
            return "DSD & Hi‑Res PCM → ALAC (CD 16/44.1 • BD 16/48 • SACD 24/48)"
        }
    }
    
    // Available profiles based on vinyl support setting
    private var availableProfiles: [OutputProfile] {
        if vm.vinylSupport {
            return OutputProfile.allCases
        } else {
            return OutputProfile.allCases.filter { $0 != .vinyl }
        }
    }
    
    private var effectiveColorScheme: ColorScheme {
        switch forceAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return systemColorScheme
        }
    }
    
    // Helper computed properties for colors that adapt to retro mode
    private var primaryTextColor: Color {
        if useRetroUI {
            // Retro mode always uses classic light colors
            return Color(red: 0.15, green: 0.15, blue: 0.15)
        } else {
            return .primary
        }
    }
    
    private var secondaryTextColor: Color {
        if useRetroUI {
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        } else {
            return .secondary
        }
    }
    
    private var controlBackground: some View {
        Group {
            if useRetroUI {
                // Retro mode always uses classic light gradients
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.90, green: 0.90, blue: 0.90),
                        Color(red: 0.82, green: 0.82, blue: 0.82)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(nsColor: .controlBackgroundColor)
            }
        }
    }
    
    private var textBackgroundColor: Color {
        if useRetroUI {
            return .white
        } else {
            return Color(nsColor: .textBackgroundColor)
        }
    }
    
    private var separatorColor: Color {
        if useRetroUI {
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        } else {
            return Color(nsColor: .separatorColor)
        }
    }
    
    private var alternatingRowColors: (Color, Color) {
        if useRetroUI {
            // Classic iTunes alternating rows (always light)
            return (Color(red: 0.98, green: 0.98, blue: 0.98), .white)
        } else {
            return (Color(nsColor: .controlAlternatingRowBackgroundColors[0]),
                    Color(nsColor: .controlAlternatingRowBackgroundColors[1]))
        }
    }

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
        .sheet(isPresented: $vm.showingFormatSupport) {
            formatSupportSheet
        }
        .preferredColorScheme(forceAppearance == "system" ? nil : effectiveColorScheme)
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
        Group {
            if useRetroUI {
                // Retro mode always uses classic light gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.94, green: 0.94, blue: 0.94),
                        Color(red: 0.88, green: 0.88, blue: 0.88)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(nsColor: .windowBackgroundColor)
            }
        }
    }
    
    private var brushedMetalHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "ipod")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(primaryTextColor.opacity(0.7))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi-Res iPod Utility")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(primaryTextColor)
                    
                    // Dynamic subtitle based on player type and preserve mode
                    Text(headerSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                // Profile logo based on selection
                profileLogo
                    .frame(height: 50)
                    .padding(.trailing, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            Group {
                if useRetroUI {
                    // Retro mode always uses classic light gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.92, green: 0.92, blue: 0.92),
                            Color(red: 0.85, green: 0.85, blue: 0.85)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color(nsColor: .controlBackgroundColor)
                }
            }
        )
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var profileLogo: some View {
        // In retro mode, always use light (1) logos
        // In modern mode, use dark/light based on appearance
        let isDark = useRetroUI ? false : (effectiveColorScheme == .dark)
        let imageName: String = {
            switch vm.profile {
            case .cd:
                return isDark ? "CD2" : "CD1"
            case .vinyl:
                return isDark ? "VINYL2" : "VINYL1"
            case .bdAudio:
                return isDark ? "BDA2" : "BDA1"
            case .sacd:
                return isDark ? "SACD2" : "SACD1"
            }
        }()
        
        return Group {
            if let nsImage = NSImage(named: imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else if let altImage = NSImage(named: NSImage.Name(imageName)) {
                Image(nsImage: altImage)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback display
                VStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(primaryTextColor.opacity(0.5))
                    Text(vm.profile.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(primaryTextColor)
                }
                .frame(width: 60, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(primaryTextColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .id(imageName)
        .onAppear {
            // Debug logging happens here, not in the view body
            print("🔍 Profile: \(vm.profile.rawValue), Retro: \(useRetroUI), Dark: \(isDark), Image: \(imageName)")
            if let nsImage = NSImage(named: imageName) {
                print("✅ Successfully loaded image: \(imageName) - Size: \(nsImage.size)")
            } else {
                print("❌ Failed to load image: \(imageName)")
            }
        }
    }
    
    private var classicControlBar: some View {
        VStack(spacing: 12) {
            // Profile selector and gain control
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Convert To:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    // Simple horizontal buttons instead of segmented control
                    HStack(spacing: 8) {
                        ForEach(availableProfiles, id: \.self) { profile in
                            HStack(spacing: 4) {
                                Button(action: { vm.profile = profile }) {
                                    Text(profile.displayName(for: vm.playerType))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(vm.profile == profile ? .white : primaryTextColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(vm.profile == profile ? Color.blue : (useRetroUI ? Color.gray.opacity(0.2) : Color.primary.opacity(0.1)))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod"))
                                
                                // Info button for Vinyl profile explaining OGG-FLAC
                                if profile == .vinyl && vm.convertToMatchDiscType && (vm.playerType == "aplayer" || vm.playerType == "epod") {
                                    Button(action: {}) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 11))
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Vinyl uses lossless FLAC codec in OGG container (not lossy Vorbis)")
                                }
                            }
                        }
                    }
                    .opacity((vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod")) ? 0.5 : 1.0)
                    
                    // Show info when disabled
                    if vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod") {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Disabled: Preserving original files")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(textBackgroundColor)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                )
                
                // Gain adjustment control
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gain Adjustment:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    HStack(spacing: 12) {
                        Slider(value: $vm.gainAdjustment, in: -20.0...20.0, step: 0.5)
                            .frame(width: 180)
                        
                        Text(String(format: "%+.1f dB", vm.gainAdjustment))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(primaryTextColor)
                            .frame(width: 70, alignment: .leading)
                        
                        Button("Reset") {
                            vm.gainAdjustment = 0.0
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text("Applies to all conversions (DSD already includes -3dB headroom)")
                        .font(.system(size: 10))
                        .foregroundColor(secondaryTextColor)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(textBackgroundColor)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                )
                
                Spacer()
                
                // Classic iTunes buttons
                HStack(spacing: 8) {
                    classiciTunesButton("File/Format Support", action: { vm.showingFormatSupport = true })
                    
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
        .background(controlBackground)
    }
    
    private func classiciTunesButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(primaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(
            Group {
                if useRetroUI {
                    // Retro mode always uses classic light gradient
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
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
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
                    .foregroundColor(.primary)
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
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("All outputs use ALAC (lossless). Warnings indicate technical steps required for iPod Classic compatibility.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
            .background(controlBackground)
            
            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
            
            // File list with alternating row colors (classic iTunes style)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.files.enumerated()), id: \.element.id) { index, file in
                        classicFileRow(file: file, isEven: index.isMultiple(of: 2))
                        
                        if index < vm.files.count - 1 {
                            Rectangle()
                                .fill(separatorColor)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .background(textBackgroundColor)
        }
        .background(textBackgroundColor)
        .cornerRadius(0)
        .padding(.horizontal, 16)
    }
    
    private func classicColumnHeader(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(primaryTextColor)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }
    
    private func classicFileRow(file: SelectedFile, isEven: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // File name
                Text(file.url.lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundColor(primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                
                // Format
                Text(file.info?.codecName.uppercased() ?? "–")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 100, alignment: .leading)
                    .padding(.horizontal, 8)
                
                // Sample Rate
                Text(file.info?.sampleRate != nil ? "\(file.info!.sampleRate) Hz" : "–")
                    .font(.system(size: 11))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 100, alignment: .leading)
                    .padding(.horizontal, 8)
                
                // Bit Depth
                Text(file.info?.bitsPerRawSample != nil ? "\(file.info!.bitsPerRawSample!)-bit" : "–")
                    .font(.system(size: 11))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 80, alignment: .leading)
                    .padding(.horizontal, 8)
                
                // Channels
                Text(file.info?.channels != nil ? "\(file.info!.channels)" : "–")
                    .font(.system(size: 11))
                    .foregroundColor(primaryTextColor)
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
            
            // Multi-stream selector (if file has multiple audio streams)
            if file.audioStreams.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Audio Streams (select one or more):")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                        .padding(.leading, 8)
                    
                    ForEach(Array(file.audioStreams.enumerated()), id: \.element.id) { index, stream in
                        HStack(spacing: 8) {
                            Button(action: {
                                if let fileIdx = vm.files.firstIndex(where: { $0.id == file.id }) {
                                    if vm.files[fileIdx].selectedStreamIndices.contains(index) {
                                        vm.files[fileIdx].selectedStreamIndices.remove(index)
                                    } else {
                                        vm.files[fileIdx].selectedStreamIndices.insert(index)
                                    }
                                }
                            }) {
                                Image(systemName: file.selectedStreamIndices.contains(index) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(file.selectedStreamIndices.contains(index) ? .blue : .gray)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("\(stream.displayName) • \(stream.sampleRate) Hz • \(stream.bitsPerRawSample ?? 0)-bit")
                                .font(.system(size: 10))
                                .foregroundColor(primaryTextColor)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
        .background(isEven ? alternatingRowColors.0 : alternatingRowColors.1)
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
                .fill(separatorColor)
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Main convert button (classic iTunes style)
                Button(action: { Task { await vm.convertAll() } }) {
                    HStack(spacing: 6) {
                        let isPreserveMode = vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod")
                        
                        Image(systemName: vm.isConverting ? "arrow.triangle.2.circlepath" : (isPreserveMode ? "doc.on.doc" : "play.circle.fill"))
                            .font(.system(size: 14))
                        Text(convertButtonLabel)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            vm.files.isEmpty || vm.isConverting ?
                            Color.gray :
                            Color.blue
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
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    if let out = vm.tempOutFolder {
                        Text("Output: \(out.lastPathComponent)")
                            .font(.system(size: 10))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    // Show preserve mode status
                    if vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod") {
                        Text("📁 Preserve Original Files mode active")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    
                    // Show FFmpeg status (only when not in preserve mode)
                    if !(vm.preserveOriginalFile && (vm.playerType == "aplayer" || vm.playerType == "epod")) {
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
                    }
                    
                    // iPod compatibility warnings (only for iPod mode)
                    if vm.playerType == "ipod" && vm.profile != .cd {
                        Text(vm.profile == .bdAudio ? "⚠️ 48 kHz may not play on iPod Classic" : "⚠️ 24-bit/48 kHz may not play on iPod Classic")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                
                // iPod scan button
                classiciTunesButton(scanButtonLabel) {  
                    vm.scanForIPods()
                    if !vm.detectedIPods.isEmpty {
                        vm.showingSyncPanel = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(controlBackground)
        }
    }
    
    private var ipodSyncPanel: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: vm.playerType == "ipod" ? "ipod" : (vm.playerType == "epod" ? "hifispeaker.2" : "smartphone"))
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    
                    Text(syncPanelTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("×") {
                        vm.showingSyncPanel = false
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                    .buttonStyle(PlainButtonStyle())
                }
                
                if vm.detectedIPods.isEmpty {
                    // No devices detected
                    VStack(spacing: 8) {
                        Image(systemName: vm.playerType == "ipod" ? "ipod" : (vm.playerType == "epod" ? "hifispeaker.2" : "smartphone"))
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Text("No \(PlayerType(rawValue: vm.playerType == "ipod" ? "iPod" : (vm.playerType == "epod" ? "ePod" : "aPlayer (Android)"))?.rawValue ?? "Devices") Detected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Connect your \(vm.playerType == "ipod" ? "iPod" : (vm.playerType == "epod" ? "ePod/DAP" : "Android player")) and click '\(scanButtonLabel)'")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                } else {
                    // iPod selection and info
                    VStack(spacing: 12) {
                        // Device picker
                        HStack {
                            Text(devicePickerLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Picker(devicePickerAccessibilityLabel, selection: $vm.selectedIPod) {
                                ForEach(vm.detectedIPods, id: \.id) { ipod in
                                    Text("\(ipod.name) (\(ipod.capacity))")
                                        .tag(ipod as DetectedIPod?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: 200)
                            
                            Spacer()
                        }
                        
                        // Selected iPod info
                        if let ipod = vm.selectedIPod {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ipod.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("\(ipod.generation) • \(ipod.capacity)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Library: \(ipod.libraryCount) songs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
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
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: { Task { await vm.syncToIPod() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: vm.syncStatus == .idle ? "arrow.down.circle" : "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14))
                                    Text(vm.syncStatus == .idle ? syncButtonLabel : vm.syncStatus.rawValue)
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
                                        Color.gray :
                                        Color.green
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
            .background(controlBackground)
        }
    }
    
    // MARK: - Format Support Sheet
    
    private var formatSupportSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("File Format & Conversion Support")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Close") {
                    vm.showingFormatSupport = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(controlBackground)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Supported Input Formats
                    supportSection(
                        title: "📥 Supported Input Formats",
                        icon: "arrow.down.circle.fill",
                        color: .blue,
                        content: [
                            ("AIFF / AIF", "Apple's lossless PCM format. Supports up to 32-bit/192+ kHz."),
                            ("WAV", "Standard PCM audio. Supports up to 32-bit/192+ kHz."),
                            ("FLAC", "Free Lossless Audio Codec. Supports up to 24-bit/192 kHz typically."),
                            ("DSF", "DSD Stream File (Direct Stream Digital). 1-bit high sample rate format."),
                            ("MKA", "Matroska Audio container. Can hold any codec (FLAC, ALAC, DTS, TrueHD, etc.). Multi-stream support!")
                        ]
                    )
                    
                    Divider()
                    
                    // Output Format
                    supportSection(
                        title: "📤 Output Format",
                        icon: "arrow.up.circle.fill",
                        color: .green,
                        content: [
                            ("ALAC (Apple Lossless)", "All conversions output to ALAC in M4A container."),
                            ("Lossless Codec", "ALAC is mathematically lossless - no quality loss during encoding."),
                            ("iPod Compatible", "ALAC is natively supported by all iPod models with album art support.")
                        ]
                    )
                    
                    Divider()
                    
                    // Output Profiles
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.purple)
                                .font(.system(size: 18))
                            Text("⚙️ Output Profiles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        profileCard(
                            name: "CD (16/44.1)",
                            specs: "16-bit / 44,100 Hz",
                            description: "Standard CD quality. Maximum iPod Classic compatibility.",
                            compatibility: "✅ Works on ALL iPod Classic models",
                            color: .green
                        )
                        
                        profileCard(
                            name: "BD AUDIO (16/48)",
                            specs: "16-bit / 48,000 Hz",
                            description: "Blu-ray audio standard. Higher sample rate than CD.",
                            compatibility: "⚠️ May not play on all iPod Classic models",
                            color: .orange
                        )
                        
                        profileCard(
                            name: "SACD/DSD (24/48)",
                            specs: "24-bit / 48,000 Hz",
                            description: "Super Audio CD quality. Highest resolution output.",
                            compatibility: "⚠️ May not play on iPod Classic (24-bit + 48 kHz)",
                            color: .orange
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                    
                    // Conversion Features
                    supportSection(
                        title: "🔧 Conversion Features",
                        icon: "gearshape.2.fill",
                        color: .orange,
                        content: [
                            ("DSD → PCM Conversion", "Automatic -3dB headroom + ultrasonic low-pass filtering (20-22 kHz)."),
                            ("Sample Rate Conversion", "High-quality SoXR resampler with 33-bit precision."),
                            ("Bit Depth Reduction", "TPDF (Triangular PDF) dithering when reducing to 16-bit."),
                            ("Channel Downmix", "Automatic stereo downmix for 5.1/7.1 surround sources."),
                            ("Gain Adjustment", "±20 dB gain control applies to all conversions."),
                            ("Multi-Stream Extraction", "MKA files with multiple audio streams can be extracted separately.")
                        ]
                    )
                    
                    Divider()
                    
                    // Multi-Stream MKA
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "waveform.path.badge.plus")
                                .foregroundColor(.cyan)
                                .font(.system(size: 18))
                            Text("🎵 Multi-Stream MKA Support")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        Text("MKA (Matroska Audio) files can contain multiple audio streams in different formats:")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            bulletPoint("Select one or more streams to extract from each file")
                            bulletPoint("Common stream types: DTS-HD MA, TrueHD, Dolby Atmos, FLAC, PCM")
                            bulletPoint("Files are organized by stream type with sequential track numbers")
                            bulletPoint("Example: All DTS 5.1 tracks first, then DTS 2.0, then Atmos, etc.")
                        }
                        .padding(.leading, 16)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cyan.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                    
                    // iPod Compatibility
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "ipod")
                                .foregroundColor(.red)
                                .font(.system(size: 18))
                            Text("🎧 Apple iPod (Including iPod Classic) Compatibility")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            compatibilityRow("✅ Guaranteed", "16-bit / 44.1 kHz ALAC", .green)
                            compatibilityRow("⚠️ Possible", "16-bit / 48 kHz ALAC", .orange)
                            compatibilityRow("❌ Unlikely", "24-bit / 48 kHz ALAC", .red)
                        }
                        
                        Text("Note: iPod Classic firmware officially supports 16/44.1. Higher specs may work on newer models but are not guaranteed.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                    
                    // Quality Notes
                    supportSection(
                        title: "ℹ️ Quality & Processing Notes",
                        icon: "info.circle.fill",
                        color: .gray,
                        content: [
                            ("Lossless Output", "ALAC encoding is mathematically lossless. No quality loss during codec conversion."),
                            ("Lossy Operations", "Sample rate changes, bit depth reduction, and DSD→PCM are lossy by nature. App warns about these."),
                            ("Metadata Preserved", "Track titles, artists, album art, and other metadata are carried over when possible."),
                            ("Album Art", "Embedded cover art is retained in the ALAC output files."),
                            ("Clipping Warning", "High gain adjustments (+10 dB or more) may cause clipping on loud tracks.")
                        ]
                    )
                }
                .padding(20)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 700, height: 800)
    }
    
    private func supportSection(title: String, icon: String, color: Color, content: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(content, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(item.1)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func profileCard(name: String, specs: String, description: String, compatibility: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text(specs)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                    )
            }
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(compatibility)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
    
    private func compatibilityRow(_ status: String, _ format: String, _ color: Color) -> some View {
        HStack {
            Text(status)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 100, alignment: .leading)
            Text(format)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
}

