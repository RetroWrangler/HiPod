<div align="center">

# 🎵 HiPod

### The Ultimate Hi-Res Audio Converter & iPod Sync Utility

*Convert DSD & Hi-Res PCM to lossless formats for iPod Classic, Digital Audio Players, and Android*

[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Xcode](https://img.shields.io/badge/Xcode-15+-blue.svg)](https://developer.apple.com/xcode/)

![HiPod Icon](.github/hipod-banner.png)

[Features](#-features) • [Supported Devices](#-supported-devices) • [Output Profiles](#%EF%B8%8F-output-profiles) • [Installation](#-installation) • [Usage](#-usage) • [Technical Details](#-technical-details)

</div>

---

## ✨ Features

### 🎧 Universal Player Support
- **iPod Classic/Video/Photo** – Full database sync with iPod_Control structure
- **Modern Hi-Res DAPs** – FiiO, Sony, Astell&Kern, HiBy, and more
- **Android Players** – Direct sync to Music folder, no drivers needed

### 🔄 Lossless Conversion Engine
- **Input Formats:** AIFF, WAV, FLAC, DSF (DSD64/128/256/512), MKA (multi-stream)
- **Output Formats:** ALAC (.m4a), FLAC, OGG-FLAC, AIFF, DSF
- **DSD→PCM Conversion:** High-quality filtering with -3 dB headroom
- **Multi-Stream MKA:** Extract one or all audio streams from Matroska files

### 🎚️ Advanced Audio Processing
- **Sample Rate Conversion:** SoXR resampler with 33-bit precision
- **Bit Depth Control:** TPDF dithering for 16-bit reduction
- **Gain Adjustment:** ±20 dB with real-time preview
- **Channel Downmix:** Automatic stereo conversion from surround

### 🎨 Classic iTunes-Inspired UI
- **Retro Mode:** Brushed metal gradients and classic styling
- **Modern Mode:** Adaptive light/dark appearance
- **Intuitive Workflow:** Drag-and-drop file selection with live warnings

### 📊 Smart Metadata Handling
- **Preserve Everything:** Album art, track titles, artists, all tags
- **Disc Identity Tagging:** Optional profile/edition labels (e.g., "Album (SACD)")
- **Custom Sub-Types:** HDCD, SHMCD, UHQCD, SACD+, and more

### 🔍 Quality Transparency
- **No Lossy Codecs:** Only ALAC, FLAC, and AIFF outputs
- **Clear Warnings:** Real-time alerts for any quality-reducing operations
- **Compatibility Checker:** iPod Classic format compatibility validation

---

## 🎧 Supported Devices

<table>
<thead>
<tr>
<th>Mode</th>
<th>Device Types</th>
<th>Output Formats</th>
<th>Features</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>iPod</strong></td>
<td>Classic, Video, Photo</td>
<td>ALAC (.m4a)</td>
<td>
• Full iPod_Control sync<br>
• iTunesDB update<br>
• F00-F49 folder structure<br>
• Album art support
</td>
</tr>
<tr>
<td><strong>ePod</strong></td>
<td>FiiO, Sony, A&K, HiBy, etc.</td>
<td>FLAC, AIFF, DSF, OGG-FLAC</td>
<td>
• SD/USB storage support<br>
• Hi-Res preservation<br>
• Native DSD support<br>
• Simple file copy
</td>
</tr>
<tr>
<td><strong>aPlayer</strong></td>
<td>Android devices</td>
<td>FLAC, AIFF, DSF, OGG-FLAC</td>
<td>
• Music folder sync<br>
• Filename preservation<br>
• No drivers required<br>
• MTP compatibility
</td>
</tr>
</tbody>
</table>

---

## 🎛️ Output Profiles

Choose from four carefully calibrated output profiles:

| Profile | Spec | Format | iPod Compatibility | Best For |
|---------|------|--------|-------------------|----------|
| **CD** | 16-bit / 44.1 kHz | ALAC | ✅ Guaranteed | Maximum compatibility |
| **BD Audio** | 16-bit / 48 kHz | ALAC | ⚠️ Possible | Blu-ray audio rips |
| **SACD/DSD** | 24-bit / 48 kHz | ALAC | ❌ Unlikely | DSD/SACD conversions |
| **Vinyl** | 24-bit / 44.1 kHz | ALAC | ⚠️ Possible | Vinyl digitization |

> **Note:** All profiles use mathematically lossless codecs. Warnings are shown for any sample rate or bit depth changes.

---

## 📥 Installation

### Requirements
- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** (for building from source)
- **FFmpeg** (bundled with app, or system installation via Homebrew)

### Option 1: Download Release (Coming Soon)
```bash
# Download the latest .dmg from Releases
# Drag HiPod.app to Applications folder
```

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/yourusername/hipod.git
cd hipod

# Open in Xcode
open HiPod.xcodeproj

# Build and run (⌘R)
```

### FFmpeg Installation
HiPod includes bundled FFmpeg binaries. If you prefer system FFmpeg:

```bash
# Install via Homebrew
brew install ffmpeg

# HiPod will auto-detect at:
# /opt/homebrew/bin/ffmpeg
# /usr/local/bin/ffmpeg
```

---

## 🚀 Usage

### Quick Start

1. **Select Player Type**
   - Go to **Settings** → **Player Type**
   - Choose: iPod, ePod, or aPlayer

2. **Choose Output Profile**
   - Main window: Select CD, BD Audio, SACD, or Vinyl
   - Profile is disabled when "Preserve Original Files" is enabled

3. **Add Files**
   - Click **Choose Files…** or drag & drop
   - Supports: AIFF, WAV, FLAC, DSF, MKA

4. **Convert**
   - Review warnings for quality-reducing operations
   - Click **Convert to [Profile] ALAC**
   - Files appear in `~/Music/HiRes-iPod-[timestamp]`

5. **Sync to Device**
   - Connect your iPod/DAP/Android device
   - Click **Scan for [Devices]**
   - Select device and click **Sync**

### Advanced Features

#### Multi-Stream MKA Extraction
For MKA files with multiple audio streams:
- Each stream appears as a checkbox option
- Select one or all streams to extract
- Streams are organized by type with sequential track numbers

#### DSD Conversion Settings
Configure target sample rates for DSD→PCM conversion:
- **DSD64 (2.8 MHz)** → 88.2, 176.4, or 352.8 kHz
- **DSD128 (5.6 MHz)** → 176.4 or 352.8 kHz
- **DSD256 (11.2 MHz)** → 352.8 or 705.6 kHz
- **DSD512 (22.5 MHz)** → 705.6 kHz

*(iPod mode always converts to 24/48 kHz for compatibility)*

#### Disc Identity Tagging
Enable in **Settings** → **Disc Handling**:
- Appends profile to album name
- Example: "Dark Side of the Moon" → "Dark Side of the Moon (SACD)"
- Customize sub-types: HDCD, SHMCD, SACD+, DSD-Digital, etc.

#### Preserve Original Files (ePod/aPlayer)
For native DSD support on compatible devices:
- Enable in **Settings** → **File Handling**
- Copies files without conversion
- Output profile selection disabled

---

## 🛠️ Technical Details

### Conversion Pipeline

```
Input File (FLAC/DSF/MKA)
    ↓
FFprobe Analysis
    ↓
Format Detection & Warnings
    ↓
FFmpeg Conversion
    • DSD: -3dB headroom + low-pass filter
    • Resample: SoXR 33-bit precision
    • Bit Depth: TPDF dithering (if reducing)
    • Channels: Stereo downmix (if >2)
    • Gain: User adjustment applied
    ↓
Metadata Embedding
    • Album art
    • Track info
    • Disc identity (optional)
    ↓
Output (ALAC/FLAC/DSF)
```

### Supported Sample Rates
- **Input:** 44.1, 48, 88.2, 96, 176.4, 192, 352.8, 384, 705.6 kHz (PCM)
- **Input:** 2.8, 5.6, 11.2, 22.5 MHz (DSD)
- **Output:** 44.1, 48, 88.2, 176.4, 352.8, 705.6 kHz (profile-dependent)

### File Organization

#### iPod Mode
```
iPod_Control/
├── Music/
│   ├── F00/
│   │   └── ABCD.m4a
│   ├── F01/
│   │   └── EFGH.m4a
│   └── ...
└── iTunes/
    └── iTunesDB
```

#### ePod/aPlayer Mode
```
Music/
├── 01 - Track Name - DSD64_24-88.flac
├── 02 - Track Name - FLAC_24-96.flac
└── ...
```

---

## 🎨 Screenshots

### Main Interface - Modern Mode
*Sleek, adaptive UI with light/dark mode support*

### Main Interface - Retro Mode
*Classic iTunes-inspired brushed metal interface with gradients*

### Settings - Player Type
*Choose between iPod Classic, ePod (DAP), or aPlayer (Android)*

### Settings - File Handling
*Configure DSD conversion, file preservation, and renaming options*

### Settings - Disc Handling
*Set up disc identity tagging with custom sub-types*

### Multi-Stream Selection
*Extract specific audio streams from MKA files*

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup
```bash
git clone https://github.com/yourusername/hipod.git
cd hipod
open HiPod.xcodeproj
```

### Areas for Contribution
- [ ] iTunesDB binary format parsing/writing improvements
- [ ] Additional player profiles and device support
- [ ] Batch processing optimizations
- [ ] Localization support (i18n)
- [ ] Automated testing suite
- [ ] Additional output format options

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **FFmpeg** – Powerful audio/video conversion engine
- **SoXR** – High-quality sample rate conversion library
- **Apple** – iPod Classic, ALAC codec, SwiftUI framework
- Inspired by the classic iTunes interface and audiophile communities worldwide

---

## 📮 Support & Contact

- **Issues:** [GitHub Issues](https://github.com/yourusername/hipod/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/hipod/discussions)
- **Email:** your.email@example.com

---

## 🗺️ Roadmap

- [ ] **v1.0** – Initial release with core features
- [ ] **v1.1** – Enhanced iTunesDB support
- [ ] **v1.2** – Batch conversion queue
- [ ] **v1.3** – Custom FFmpeg filter chains
- [ ] **v2.0** – Plugin architecture for custom processors
- [ ] **v2.1** – Network sync support
- [ ] **v2.2** – Playlist management

---

## ❓ FAQ

**Q: Will this work with my iPod Nano/Shuffle?**  
A: HiPod is optimized for iPod Classic/Video/Photo models with the iPod_Control structure. Nano/Shuffle support is planned for future releases.

**Q: Does this modify my original files?**  
A: No! All conversions create new files in a designated output folder. Your originals remain untouched.

**Q: What's the difference between ePod and aPlayer modes?**  
A: ePod mode is for generic DAPs (FiiO, Sony, etc.) with simple file copying. aPlayer mode is specifically for Android devices with Music folder organization.

**Q: Can I convert Apple Music/iTunes Store purchases?**  
A: No. HiPod only works with DRM-free audio files. Protected AAC files from iTunes Store cannot be converted.

**Q: Does the retro UI affect performance?**  
A: Not at all! The retro UI is purely cosmetic and has no impact on conversion speed or quality.

**Q: How does DSD conversion work?**  
A: DSD files are converted to PCM using FFmpeg with -3dB headroom to prevent clipping and an ultrasonic low-pass filter. You can configure target sample rates in Settings.

---

<div align="center">

**Made with ❤️ for audiophiles and iPod enthusiasts**

⭐️ Star this repo if you find it useful!

[Report Bug](https://github.com/yourusername/hipod/issues) • [Request Feature](https://github.com/yourusername/hipod/issues) • [Contribute](https://github.com/yourusername/hipod/pulls)

</div>
