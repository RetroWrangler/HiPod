//
//  HiPodApp.swift
//  HiPod
//
//  Created by Cory on 10/22/25.
//

import SwiftUI

@main
struct HiPodApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Settings {
            SettingsView()
        }
    }
}
// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("useRetroUI") private var useRetroUI = false
    @AppStorage("forceAppearance") private var forceAppearance = "system" // "system", "light", "dark"
    
    var body: some View {
        TabView {
            AppearanceSettings(useRetroUI: $useRetroUI, forceAppearance: $forceAppearance)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(0)
            
            PlayerSettings()
                .tabItem {
                    Label("Player Type", systemImage: "hifispeaker")
                }
                .tag(1)
            
            FileHandlingSettings()
                .tabItem {
                    Label("File Handling", systemImage: "doc.on.doc")
                }
                .tag(2)
            
            DiscHandlingSettings()
                .tabItem {
                    Label("Disc Handling", systemImage: "opticaldisc")
                }
                .tag(3)
        }
        .frame(width: 600, height: 550)
    }
}

struct AppearanceSettings: View {
    @Binding var useRetroUI: Bool
    @Binding var forceAppearance: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Appearance Settings")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Divider()
                
                VStack(spacing: 16) {
                    // Retro UI Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use Retro iTunes-Style UI", isOn: $useRetroUI)
                            .toggleStyle(SwitchToggleStyle())
                        
                        Text("Enable classic iTunes-inspired design with gradients and brushed metal. Always uses light appearance.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Appearance Override
                    VStack(alignment: .center, spacing: 12) {
                        Text("Appearance Mode:")
                            .font(.system(size: 13, weight: .medium))
                        
                        Picker("", selection: $forceAppearance) {
                            Text("Follow System").tag("system")
                            Text("Always Light").tag("light")
                            Text("Always Dark").tag("dark")
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                        .labelsHidden()
                        .disabled(useRetroUI)
                        
                        Text(useRetroUI ? "Appearance mode is disabled when Retro UI is enabled." : "Override the system appearance. Restart may be required.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}

struct PlayerSettings: View {
    @AppStorage("playerType") private var playerType = "ipod"
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Player Type")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            Text("Select the type of audio player you'll be syncing to")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            
            // Three icons horizontally
            HStack(spacing: 40) {
                // iPod
                PlayerTypeButton(
                    icon: "ipod",
                    title: "iPod",
                    color: .blue,
                    isSelected: playerType == "ipod"
                ) {
                    playerType = "ipod"
                }
                
                // ePod
                PlayerTypeButton(
                    icon: "hifispeaker.2",
                    title: "ePod",
                    color: .orange,
                    isSelected: playerType == "epod"
                ) {
                    playerType = "epod"
                }
                
                // aPlayer (Android)
                PlayerTypeButton(
                    icon: "smartphone",
                    title: "aPlayer",
                    color: .green,
                    isSelected: playerType == "aplayer"
                ) {
                    playerType = "aplayer"
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Explanation panel at bottom
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon
                HStack(spacing: 8) {
                    Image(systemName: playerTypeIcon)
                        .font(.system(size: 20))
                        .foregroundColor(playerTypeColor)
                    
                    Text(playerTypeTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text(playerTypeDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(playerTypeFeatures, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(playerTypeColor)
                            Text(feature)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(playerTypeColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(playerTypeColor.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .padding(20)
        }
    }
    
    // Computed properties for the selected player type
    private var playerTypeIcon: String {
        switch playerType {
        case "ipod": return "ipod"
        case "epod": return "hifispeaker.2"
        case "aplayer": return "smartphone"
        default: return "questionmark.circle"
        }
    }
    
    private var playerTypeColor: Color {
        switch playerType {
        case "ipod": return .blue
        case "epod": return .orange
        case "aplayer": return .green
        default: return .gray
        }
    }
    
    private var playerTypeTitle: String {
        switch playerType {
        case "ipod": return "iPod Classic"
        case "epod": return "ePod (Digital Audio Player)"
        case "aplayer": return "aPlayer (Android)"
        default: return "Unknown"
        }
    }
    
    private var playerTypeDescription: String {
        switch playerType {
        case "ipod":
            return "Apple iPod Classic models with iPod_Control database structure. The app will sync files using the traditional iPod file organization system."
        case "epod":
            return "Generic digital audio players, DAPs, and SD card readers. Simple file copying without special database management. Perfect for Hi-Res audio players."
        case "aplayer":
            return "Android-based music players with folder navigation. Files are organized in a standard Music folder structure that Android apps can read."
        default:
            return "No player type selected"
        }
    }
    
    private var playerTypeFeatures: [String] {
        switch playerType {
        case "ipod":
            return [
                "Syncs to iPod Classic, iPod Video, iPod Photo",
                "Updates iTunesDB database automatically",
                "Organizes files in iPod_Control/Music structure",
                "Creates proper folder hierarchy (F00-F49)"
            ]
        case "epod":
            return [
                "Detects all removable storage devices",
                "Simple file copy to root or Music folder",
                "No database management required",
                "Works with any player that reads M4A files",
                "Supports Hi-Res audio when preserving originals"
            ]
        case "aplayer":
            return [
                "Detects Android file system structure",
                "Copies files to Music folder",
                "Preserves original filenames and metadata",
                "Compatible with any Android music player app"
            ]
        default:
            return []
        }
    }
}

// MARK: - Player Type Button Component

struct PlayerTypeButton: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? color : Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? color : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .frame(width: 120)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - File Handling Settings

struct FileHandlingSettings: View {
    @AppStorage("playerType") private var playerType = "ipod"
    @AppStorage("preserveOriginalFile") private var preserveOriginalFile = false
    @AppStorage("pcmRequired") private var pcmRequired = false
    @AppStorage("dsdConversionMode") private var dsdConversionMode = "auto" // "auto", "custom"
    @AppStorage("dsd64TargetRate") private var dsd64TargetRate = 88200
    @AppStorage("dsd128TargetRate") private var dsd128TargetRate = 176400
    @AppStorage("dsd256TargetRate") private var dsd256TargetRate = 352800
    @AppStorage("dsd512TargetRate") private var dsd512TargetRate = 705600
    @AppStorage("renameFiles") private var renameFiles = true  // Track number + metadata naming
    @State private var showingPCMInfo = false
    
    private var isNonIPod: Bool {
        playerType == "aplayer" || playerType == "epod"
    }
    
    private var isIPod: Bool {
        playerType == "ipod"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("File Handling")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            Text("Configure how audio files are processed and copied")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preserve Original File option (only for aPlayer/ePod)
                    if isNonIPod {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $preserveOriginalFile) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.badge.arrow.up")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Preserve Original Files")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Copy files as-is without any conversion")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle())
                            
                            Text("When enabled, files are copied directly to your device without conversion. This preserves the original quality and format (FLAC, WAV, DSF, etc.) but requires your player to support these formats natively.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if preserveOriginalFile {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Output profile selection is disabled when preserving original files")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                }
                                .padding(.leading, 26)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // PCM Required option (available for all player types)
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $pcmRequired) {
                            HStack(spacing: 8) {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 18))
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PCM Required (Convert DSD)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Always convert DSD files to PCM format")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(preserveOriginalFile && isNonIPod || isIPod)
                        
                        if isIPod {
                            Text("iPod mode always converts DSD to PCM. This setting is disabled in iPod mode.")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("DSD (Direct Stream Digital) files will be converted to PCM using high-quality filtering. Useful if your player doesn't support DSD natively or you prefer PCM playback.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // "Learn More" button
                        Button(action: { showingPCMInfo = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "book.circle")
                                    .font(.system(size: 12))
                                Text("Learn about DSD vs PCM")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 26)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .opacity((preserveOriginalFile && isNonIPod) || isIPod ? 0.5 : 1.0)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // File Naming Options
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $renameFiles) {
                            HStack(spacing: 8) {
                                Image(systemName: "textformat.123")
                                    .font(.system(size: 18))
                                    .foregroundColor(.indigo)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rename Files with Track Numbers")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Add track numbers and format info to filenames")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle())
                        
                        if renameFiles {
                            Text("Files will be named: '01 - Song Name - Format_Spec.ext'")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Original filenames will be preserved (e.g., 'Song Name.flac')")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.indigo.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // DSD Conversion Settings
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 18))
                                .foregroundColor(.cyan)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DSD to PCM Conversion Settings")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Configure target sample rates for DSD conversion")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if isIPod {
                            // iPod mode: show locked settings
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("iPod Mode: Fixed Conversion")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("While in iPod mode, all DSD files are converted to 24-bit/48 kHz PCM, as iPod Classic cannot support higher sample rates.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Text("All DSD (64/128/256/512) → 24-bit / 48 kHz")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.blue)
                                            .padding(.top, 4)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        } else {
                            // aPlayer/DAP mode: show configurable settings
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Choose target sample rates for each DSD type:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 12) {
                                    dsdConversionRow(
                                        title: "DSD64 (2.8 MHz)",
                                        options: [88200, 176400, 352800],
                                        selection: $dsd64TargetRate,
                                        recommended: 88200
                                    )
                                    
                                    Divider()
                                    
                                    dsdConversionRow(
                                        title: "DSD128 (5.6 MHz)",
                                        options: [176400, 352800],
                                        selection: $dsd128TargetRate,
                                        recommended: 176400
                                    )
                                    
                                    Divider()
                                    
                                    dsdConversionRow(
                                        title: "DSD256 (11.2 MHz)",
                                        options: [352800, 705600],
                                        selection: $dsd256TargetRate,
                                        recommended: 352800
                                    )
                                    
                                    Divider()
                                    
                                    dsdConversionRow(
                                        title: "DSD512 (22.5 MHz)",
                                        options: [705600],
                                        selection: $dsd512TargetRate,
                                        recommended: 705600
                                    )
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                )
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.cyan)
                                    Text("These settings apply when 'PCM Required' is enabled or when converting for aPlayer/ePod")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cyan.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .opacity((preserveOriginalFile && isNonIPod) ? 0.5 : 1.0)
                    
                    // iPod notice
                    if !isNonIPod {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "ipod")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("iPod Mode")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("iPod Classic requires ALAC format. All files will be converted to ALAC regardless of these settings. The 'Preserve Original Files' option is only available for aPlayer and ePod modes.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showingPCMInfo) {
            PCMInfoSheet()
        }
    }
    
    // Helper function for DSD conversion row
    private func dsdConversionRow(title: String, options: [Int], selection: Binding<Int>, recommended: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                if options.count > 1 {
                    Text("Recommended: \(formatSampleRate(recommended))")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("24-bit /")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if options.count == 1 {
                    // Only one option - show as text
                    Text(formatSampleRate(options[0]))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                } else {
                    // Multiple options - show as picker
                    Picker("", selection: selection) {
                        ForEach(options, id: \.self) { rate in
                            Text(formatSampleRate(rate)).tag(rate)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
            }
        }
    }
    
    private func formatSampleRate(_ rate: Int) -> String {
        let khz = Double(rate) / 1000.0
        return String(format: "%.1f kHz", khz)
    }
}

// MARK: - PCM Info Sheet

struct PCMInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.path.badge.magnifyingglass")
                    .font(.system(size: 22))
                    .foregroundColor(.purple)
                
                Text("DSD vs PCM: Understanding the Difference")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Overview
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                            Text("What are DSD and PCM?")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("DSD (Direct Stream Digital) and PCM (Pulse Code Modulation) are two different methods of encoding digital audio. Each has unique characteristics that affect compatibility and playback.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                    
                    // Comparison Table
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comparison")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 0) {
                            // Header row
                            HStack(spacing: 0) {
                                Text("Feature")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                
                                Divider()
                                
                                Text("DSD")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(10)
                                    .background(Color.purple.opacity(0.1))
                                
                                Divider()
                                
                                Text("PCM")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(10)
                                    .background(Color.green.opacity(0.1))
                            }
                            .frame(height: 36)
                            
                            Divider()
                            
                            // Data rows
                            comparisonRow("Encoding", "1-bit delta-sigma", "Multi-bit samples")
                            Divider()
                            comparisonRow("Sample Rate", "2.8 MHz - 11.2 MHz", "44.1 kHz - 192 kHz")
                            Divider()
                            comparisonRow("Bit Depth", "1-bit", "16-bit, 24-bit, 32-bit")
                            Divider()
                            comparisonRow("File Formats", "DSF, DFF", "FLAC, WAV, AIFF, ALAC")
                            Divider()
                            comparisonRow("iPod Classic", "❌ Not Supported", "✅ Fully Supported")
                            Divider()
                            comparisonRow("Most DAPs", "⚠️ Limited Support", "✅ Universal Support")
                            Divider()
                            comparisonRow("File Size", "Large (5-6 MB/min)", "Medium (2-3 MB/min)")
                            Divider()
                            comparisonRow("Editing", "❌ Difficult", "✅ Easy")
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Conversion details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                                .font(.system(size: 18))
                            Text("DSD to PCM Conversion")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            bulletPoint("Applies -3 dB headroom to prevent clipping", color: .orange)
                            bulletPoint("Uses ultrasonic low-pass filter (adaptive based on target rate)", color: .orange)
                            bulletPoint("High-quality SoXR resampler with 33-bit precision", color: .orange)
                            bulletPoint("Always outputs 24-bit PCM for maximum quality", color: .orange)
                            bulletPoint("Target sample rate depends on player type and settings", color: .orange)
                        }
                        
                        // DSD Conversion Rates Table
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended DSD Conversion Rates:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.top, 8)
                            
                            VStack(spacing: 0) {
                                // Header
                                HStack(spacing: 0) {
                                    Text("DSD Type")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                    
                                    Divider()
                                    
                                    Text("Native Rate")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                    
                                    Divider()
                                    
                                    Text("Recommended PCM")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                    
                                    Divider()
                                    
                                    Text("iPod Mode")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                }
                                
                                Divider()
                                
                                dsdConversionTableRow("DSD64", "2.8 MHz", "88.2 kHz", "48 kHz*")
                                Divider()
                                dsdConversionTableRow("DSD128", "5.6 MHz", "176.4 kHz", "48 kHz*")
                                Divider()
                                dsdConversionTableRow("DSD256", "11.2 MHz", "352.8 kHz", "48 kHz*")
                                Divider()
                                dsdConversionTableRow("DSD512", "22.5 MHz", "705.6 kHz", "48 kHz*")
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(6)
                            
                            Text("* iPod Classic requires all DSD to be converted to 24/48 PCM for compatibility")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 18))
                            Text("Recommendations")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            recommendationCard(
                                icon: "ipod",
                                title: "For iPod Classic",
                                description: "Always convert DSD to PCM. iPod requires ALAC/PCM format.",
                                color: .blue
                            )
                            
                            recommendationCard(
                                icon: "hifispeaker.2",
                                title: "For ePod (Hi-Res DAP)",
                                description: "Enable 'Preserve Original Files' if your ePod supports DSD natively for best quality.",
                                color: .orange
                            )
                            
                            recommendationCard(
                                icon: "smartphone",
                                title: "For aPlayer (Android)",
                                description: "Check if your player supports DSD. If not, enable 'PCM Required'.",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(20)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 650, height: 700)
    }
    
    private func comparisonRow(_ feature: String, _ dsd: String, _ pcm: String) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            Text(dsd)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
            
            Divider()
            
            Text(pcm)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
        }
        .frame(height: 32)
    }
    
    private func dsdConversionTableRow(_ type: String, _ native: String, _ recommended: String, _ ipod: String) -> some View {
        HStack(spacing: 0) {
            Text(type)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.orange.opacity(0.1))
            
            Divider()
            
            Text(native)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
            
            Divider()
            
            Text(recommended)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
            
            Divider()
            
            Text(ipod)
                .font(.system(size: 11))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
        }
        .frame(height: 32)
    }
    
    private func bulletPoint(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func recommendationCard(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Disc Handling Settings

struct DiscHandlingSettings: View {
    @AppStorage("addDiscIdentity") private var addDiscIdentity = false
    @AppStorage("vinylSupport") private var vinylSupport = false
    @AppStorage("convertToMatchDiscType") private var convertToMatchDiscType = false
    @AppStorage("playerType") private var playerType = "ipod"
    
    // Disc sub-type selections
    @AppStorage("cdSubType") private var cdSubType = "CD"
    @AppStorage("sacDSubType") private var sacdSubType = "SACD"
    @AppStorage("vinylSubType") private var vinylSubType = "LP"
    @AppStorage("bdaSubType") private var bdaSubType = "BDA"
    
    private var isNonIPod: Bool {
        playerType == "aplayer" || playerType == "epod"
    }
    
    // Sub-type options
    private let cdSubTypes = ["CD", "HDCD", "SHMCD", "UHQCD"]
    private let sacdSubTypes = ["SACD", "SACD+", "DSD-Digital"]
    private let vinylSubTypes = ["LP", "EP", "Vinyl Rip", "Single"]
    private let bdaSubTypes = ["BDA", "Blu-Ray Audio", "Custom Blu-Ray", "Blu-Ray Rip"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Disc Handling")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            Text("Configure disc-related features and metadata")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Vinyl Support Setting
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $vinylSupport) {
                            HStack(spacing: 8) {
                                Image(systemName: "circle.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Vinyl/LP Support")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Add vinyl as an output profile option")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle())
                        
                        if vinylSupport {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Vinyl profile adds 'LP' as an output option on the main screen.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 26)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.orange)
                                        Text("Vinyl Specifications:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.leading, 26)
                                    
                                    Text("• iPod Mode: 24-bit / 44.1 kHz (ALAC)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 42)
                                    
                                    Text("• ePod/aPlayer Mode: Preserves source quality")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 42)
                                }
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    Text("Vinyl rips typically use 24-bit depth to capture the full dynamic range. 44.1 kHz matches most vinyl digitization standards.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, 26)
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Vinyl/LP profile is disabled. Only CD, BD Audio, and SACD profiles will be available.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Disc Identity Setting
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $addDiscIdentity) {
                            HStack(spacing: 8) {
                                Image(systemName: "tag.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(.pink)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Add Disc Identity to Album Tags")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Append disc type to album name in metadata")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle())
                        
                        if addDiscIdentity {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("When enabled, the output profile type will be appended to the album name in parentheses.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 26)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Text("Examples:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.leading, 26)
                                
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "opticaldisc")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blue)
                                            Text("CD Profile:")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                        Text("\"Rumours\" → \"Rumours (CD)\"")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 16)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "opticaldiscdrive")
                                                .font(.system(size: 10))
                                                .foregroundColor(.green)
                                            Text("BD Audio Profile:")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.green)
                                        }
                                        Text("\"Kind of Blue\" → \"Kind of Blue (BDA)\"")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 16)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.leading, 26)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "laser.burst")
                                            .font(.system(size: 10))
                                            .foregroundColor(.purple)
                                        Text("SACD Profile:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.purple)
                                    }
                                    Text("\"Dark Side of the Moon\" → \"Dark Side of the Moon (SACD)\"")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 16)
                                }
                                .padding(.leading, 26)
                                
                                if vinylSupport {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "circle.circle")
                                                .font(.system(size: 10))
                                                .foregroundColor(.orange)
                                            Text("Vinyl Profile:")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.orange)
                                        }
                                        Text("\"Abbey Road\" → \"Abbey Road (LP)\"")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 16)
                                    }
                                    .padding(.leading, 26)
                                }
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.pink)
                                    Text("This helps you identify the source quality on your player when you have multiple versions of the same album.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, 26)
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Album names in metadata will remain unchanged from the source files.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.pink.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Disc Sub-Type Selector (only shown if disc identity is enabled)
                    if addDiscIdentity {
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cyan)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Disc Sub-Types")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Customize the disc identity tag for each profile")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 16) {
                                // CD Sub-Type
                                HStack {
                                    Image(systemName: "opticaldisc")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text("CD Profile:")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Picker("", selection: $cdSubType) {
                                        ForEach(cdSubTypes, id: \.self) { type in
                                            Text(type).tag(type)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 150)
                                    
                                    Text("Example: \"Album (\(cdSubType))\"")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Vinyl Sub-Type (only if vinyl support is enabled)
                                if vinylSupport {
                                    HStack {
                                        Image(systemName: "circle.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        
                                        Text("Vinyl Profile:")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 120, alignment: .leading)
                                        
                                        Picker("", selection: $vinylSubType) {
                                            ForEach(vinylSubTypes, id: \.self) { type in
                                                Text(type).tag(type)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .frame(width: 150)
                                        
                                        Text("Example: \"Album (\(vinylSubType))\"")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // BD Audio Sub-Type
                                HStack {
                                    Image(systemName: "opticaldiscdrive")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                        .frame(width: 24)
                                    
                                    Text("BD Audio Profile:")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Picker("", selection: $bdaSubType) {
                                        ForEach(bdaSubTypes, id: \.self) { type in
                                            Text(type).tag(type)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 150)
                                    
                                    Text("Example: \"Album (\(bdaSubType))\"")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                // SACD Sub-Type
                                HStack {
                                    Image(systemName: "laser.burst")
                                        .font(.system(size: 14))
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    
                                    Text("SACD Profile:")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Picker("", selection: $sacdSubType) {
                                        ForEach(sacdSubTypes, id: \.self) { type in
                                            Text(type).tag(type)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 150)
                                    
                                    Text("Example: \"Album (\(sacdSubType))\"")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 26)
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cyan)
                                Text("These sub-types allow you to distinguish between different disc editions and formats. The selected sub-type will be used in the album metadata tag.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 26)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Convert to Match Disc Type Setting
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $convertToMatchDiscType) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 18))
                                    .foregroundColor(.teal)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Convert File to Match Disc Type")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Output format matches the selected disc profile")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(!isNonIPod)
                        
                        if !isNonIPod {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("This setting is only available for aPlayer and ePod modes. iPod mode always uses ALAC format.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 26)
                        } else if convertToMatchDiscType {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Output files will be converted to format-specific containers based on the selected profile:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 26)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "opticaldisc")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                            .frame(width: 20)
                                        Text("CD → AIFF")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 150, alignment: .leading)
                                        Text("16-bit PCM in AIFF container")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "opticaldiscdrive")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                            .frame(width: 20)
                                        Text("BD Audio → MKA")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 150, alignment: .leading)
                                        Text("FLAC in Matroska container")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "laser.burst")
                                            .font(.system(size: 12))
                                            .foregroundColor(.purple)
                                            .frame(width: 20)
                                        Text("SACD → FLAC/DSF")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 150, alignment: .leading)
                                        Text("FLAC for PCM, DSF preserved for DSD")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if vinylSupport {
                                        HStack(spacing: 8) {
                                            Image(systemName: "circle.circle")
                                                .font(.system(size: 12))
                                                .foregroundColor(.orange)
                                                .frame(width: 20)
                                            HStack(spacing: 4) {
                                                Text("Vinyl → OGG-FLAC")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .frame(width: 150, alignment: .leading)
                                                Button(action: {}) {
                                                    Image(systemName: "info.circle")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.orange)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .help("Lossless FLAC codec in OGG container (not lossy Vorbis)")
                                            }
                                            Text("Lossless FLAC in OGG container")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.leading, 26)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.teal)
                                    Text("All formats remain lossless. This feature helps organize your library by using industry-standard containers for each disc type.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, 26)
                            }
                            .padding(.top, 4)
                        } else {
                            Text("All files will be converted to FLAC format regardless of disc type.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.teal.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.teal.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .opacity(!isNonIPod ? 0.5 : 1.0)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Info panel about metadata preservation
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            
                            Text("Metadata Preservation")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            metadataInfoRow(icon: "music.note", text: "Track titles, artists, and album information are preserved", color: .blue)
                            metadataInfoRow(icon: "photo", text: "Embedded album artwork is retained in output files", color: .blue)
                            metadataInfoRow(icon: "number", text: "Track numbers and disc numbers are maintained", color: .blue)
                            metadataInfoRow(icon: "calendar", text: "Release dates and genres are carried over", color: .blue)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(20)
            }
        }
    }
    
    private func metadataInfoRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}


