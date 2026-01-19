# 🎵 HiPod – The Ultimate Hi-Res Audio Sync & iPod Utility

> **DSD & Hi‑Res PCM → ALAC for iPod Classic, DAPs, and Android**

![HiPod Icon](.github/hipod-banner.png)

---

## 🚀 Features at a Glance

- **Universal Player Support:**
  - iPod Classic (full database sync, iPod_Control structure)
  - Modern Hi-Res DAPs/ePods (SD/USB storage, FiiO, Sony, Astell&Kern, HiBy, and more)
  - Android-based players (‘aPlayer’ mode, direct to Music folder)
- **Lossless Conversion Engine:**
  - Input: AIFF, WAV, FLAC, DSF (DSD64/128/256/512), MKA (multi-stream)
  - Output: ALAC (.m4a), FLAC, OGG-FLAC, AIFF (per profile and device)
  - DSD→PCM conversion with -3 dB headroom & high-quality filtering
- **Advanced Profiles:**
  - CD (16/44.1), BD AUDIO (16/48), SACD/DSD (24/48), Vinyl/LP (24/44.1, optional)
  - Automatic compatibility warnings for iPod Classic
- **Multi-Stream MKA Handling:**
  - Choose and extract all or specific streams from Matroska audio files
- **Metadata Magic:**
  - Preserve album art, track titles, artists, and all tags
  - Disc identity tagging: append edition/profile to album name
- **Retro iTunes-Inspired UI:**
  - Toggle classic brushed metal and gradients for the full nostalgia trip
- **Smart Sync:**
  - Device detection and tailored file organization
  - Updates iPod iTunesDB; builds folder hierarchies (F00–F49)
- **Audiophile Options:**
  - Gain adjustment (±20 dB), downmix, track numbering, format-based renaming
  - Configure DSD conversion rates and preservation per device
- **No Lossy Codecs, Ever:**
  - Only lossless ALAC/FLAC/AIFF. App warns clearly about any quality‑reducing operation.

---

## 🎧 Supported Devices & Modes

| Mode         | Features                                                      | Output Formats              |
|--------------|---------------------------------------------------------------|-----------------------------|
| **iPod**     | Classic, Video, Photo – iPod_Control sync, iTunesDB update    | ALAC (.m4a)                 |
| **ePod**     | Hi-Res DAPs, SD/USB, file copy to Music/root, preserves PCM   | FLAC, AIFF, OGG-FLAC, DSF   |
| **aPlayer**  | Android, Music folder, preserves filenames, no drivers needed | FLAC, AIFF, OGG-FLAC, DSF   |


---

## 🎚️ Output Profiles (User-Selectable)

- **CD:** 16‑bit / 44.1 kHz (ALAC) — _Maximum iPod compatibility_
- **BD AUDIO:** 16‑bit / 48 kHz (ALAC) — _May not play on all iPods_
- **SACD/DSD:** 24‑bit / 48 kHz (ALAC) — _High-res, not guaranteed on iPod Classic_
- **VINYL/LP:** 24‑bit / 44.1 kHz (optional) — _Capture vinyl rips in full depth_

All conversions use mathematically lossless codecs. The app always surfaces any resampling, bit-depth reduction, or DSD→PCM conversion steps!

---

## 📦 Installation

### Requirements
- **macOS 14.0+** (Sonoma or later recommended)
- **Xcode 15.0+** (for building from source)
- **FFmpeg** (bundled with app, or install via Homebrew)

### Build from Source
```bash
# 1. Clone the repository
$ git clone https://github.com/yourusername/hipod.git
$ cd hipod

# 2. Open in Xcode
$ open HiPod.xcodeproj

# 3. Build and Run (⌘R)
```

### FFmpeg Setup
HiPod includes bundled FFmpeg binaries for convenience. If you prefer to use system FFmpeg:
```bash
# Install via Homebrew
$ brew install ffmpeg

# HiPod will auto-detect FFmpeg at:
# • /opt/homebrew/bin/ffmpeg (Apple Silicon)
# • /usr/local/bin/ffmpeg (Intel Mac)
# • Bundled binaries (fallback)
```

---

## 🚀 Quick Start Guide

### 1. Configure Player Type
- Open **HiPod** → **Settings** (⌘,)
- Navigate to **Player Type** tab
- Select your target device:
  - **iPod** – For iPod Classic, Video, or Photo
  - **ePod** – For Hi-Res DAPs (FiiO, Sony, A&K, etc.)
  - **aPlayer** – For Android-based music players

### 2. Select Output Profile
In the main window, choose your desired output profile:
- **CD (16/44.1)** – Maximum iPod compatibility ✅
- **BD Audio (16/48)** – Blu-ray audio quality ⚠️
- **SACD/DSD (24/48)** – High-res conversion ❌
- **Vinyl (24/44.1)** – For vinyl rips (optional)

> **Note:** Profile selection is disabled when "Preserve Original Files" is enabled for ePod/aPlayer modes.

### 3. Add Your Audio Files
- Click **Choose Files…** or drag and drop
- Supported formats: AIFF, WAV, FLAC, DSF, MKA
- Files are automatically analyzed for format and quality

### 4. Review Warnings
HiPod provides transparent warnings for any quality-affecting operations:
- DSD→PCM conversion details
- Sample rate changes
- Bit depth reduction
- Channel downmixing

### 5. Convert
- Click **Convert to [Profile] ALAC** (or **Copy Original Files** if preserving)
- Progress shown for each file
- Output folder: `~/Music/HiRes-iPod-[timestamp]`
- Click **Show in Finder** to view results

### 6. Sync to Device
- Connect your iPod/DAP/Android player
- Click **Scan for [Devices]**
- Select your device from the dropdown
- Review sync info (capacity, library count)
- Click **Sync to [Device]**

---

## ⚙️ Advanced Features

### Multi-Stream MKA Extraction
For Matroska audio files containing multiple streams:

- **Automatic Detection:** All audio streams are detected and listed
- **Selective Extraction:** Choose which streams to extract (checkboxes)
- **Stream Information:** Codec, sample rate, bit depth, channels shown
- **Organized Output:** Streams grouped by type with sequential track numbering
- **Common Formats:** DTS-HD MA, TrueHD, Dolby Atmos, FLAC, PCM

**Example Workflow:**
1. Add MKA file with 3 streams (DTS 5.1, DTS 2.0, Commentary)
2. Select desired streams via checkboxes
3. Convert – each stream becomes a separate output file
4. Files named: `01 - Title - DTS 5.1_format.m4a`, `02 - Title - DTS 2.0_format.m4a`

### DSD Conversion Settings
Fine-tune DSD→PCM conversion target sample rates in **Settings** → **File Handling**:

| DSD Type | Native Rate | Recommended PCM | Options |
|----------|-------------|-----------------|---------|
| **DSD64** | 2.8 MHz | 88.2 kHz | 88.2, 176.4, 352.8 kHz |
| **DSD128** | 5.6 MHz | 176.4 kHz | 176.4, 352.8 kHz |
| **DSD256** | 11.2 MHz | 352.8 kHz | 352.8, 705.6 kHz |
| **DSD512** | 22.5 MHz | 705.6 kHz | 705.6 kHz |

> **iPod Mode Override:** All DSD conversions use 24-bit/48 kHz for maximum compatibility.

**Processing Details:**
- **Headroom:** -3 dB applied to prevent clipping
- **Low-Pass Filter:** Ultrasonic filtering (adaptive 20-22 kHz)
- **Resampler:** SoXR with 33-bit precision
- **Bit Depth:** Always 24-bit PCM output

### Disc Identity Tagging
Add disc type information to album metadata:

**Enable in Settings → Disc Handling:**
1. Toggle "Add Disc Identity to Album Tags"
2. Customize sub-types for each profile:
   - **CD:** CD, HDCD, SHMCD, UHQCD
   - **SACD:** SACD, SACD+, DSD-Digital
   - **Vinyl:** LP, EP, Vinyl Rip, Single
   - **BD Audio:** BDA, Blu-Ray Audio, Custom Blu-Ray

**Examples:**
- Input: `"Dark Side of the Moon"`
- Output: `"Dark Side of the Moon (SACD)"`

**Benefits:**
- Easily identify source quality on your player
- Organize multiple versions of the same album
- Preserve edition information

### Preserve Original Files (ePod/aPlayer Only)
For devices with native DSD/Hi-Res support:

**Enable in Settings → File Handling:**
- Files copied without conversion
- Original format, bit depth, and sample rate maintained
- Useful for DSD-capable DAPs
- Output profile selection disabled
- Fast copy operation

### Gain Adjustment
Apply volume adjustment to all conversions:

- **Range:** ±20 dB
- **Precision:** 0.5 dB steps
- **Applied After:** DSD headroom (if applicable)
- **Use Case:** Normalize quiet recordings or reduce hot masters

> **Warning:** Positive gain > +10 dB may cause clipping on loud tracks.

### Format Matching (ePod/aPlayer)
Enable "Convert File to Match Disc Type" for format-specific containers:

| Profile | Output Format | Container | Notes |
|---------|---------------|-----------|-------|
| **CD** | PCM 16-bit | AIFF | CD-quality lossless |
| **BD Audio** | FLAC | MKA (Matroska) | Blu-ray standard |
| **SACD** | FLAC/DSF | FLAC or DSF | DSD preserved if possible |
| **Vinyl** | FLAC | OGG container | Lossless FLAC in OGG |

---

## 🛠️ Technical Details

### Audio Processing Pipeline

```
┌─────────────────────┐
│   Input File        │
│ (FLAC/DSF/WAV/MKA) │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  FFprobe Analysis   │
│  • Format detection │
│  • Stream analysis  │
│  • Metadata reading │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Quality Warnings   │
│  • Sample rate      │
│  • Bit depth        │
│  • DSD conversion   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  FFmpeg Processing  │
│  ├─ DSD: -3dB + LP  │
│  ├─ Resample: SoXR  │
│  ├─ Dither: TPDF    │
│  ├─ Downmix: Stereo │
│  └─ Gain: User adj  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Metadata Embedding  │
│  • Album art        │
│  • Track info       │
│  • Disc identity    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Output File       │
│ (ALAC/FLAC/DSF)     │
└─────────────────────┘
```

### Supported Formats

**Input Formats:**
- **AIFF/AIF** – Apple Interchange File Format (PCM)
- **WAV** – Waveform Audio File Format (PCM)
- **FLAC** – Free Lossless Audio Codec
- **DSF** – DSD Stream File (1-bit DSD)
- **MKA** – Matroska Audio Container (any codec)

**Output Formats:**
- **ALAC** – Apple Lossless Audio Codec (.m4a) [iPod mode]
- **FLAC** – Free Lossless Audio Codec [ePod/aPlayer]
- **AIFF** – PCM in AIFF container [CD profile, ePod/aPlayer]
- **OGG-FLAC** – Lossless FLAC in OGG container [Vinyl profile]
- **DSF** – DSD preserved [ePod/aPlayer with preserve mode]

### Sample Rate Support

**Input (PCM):**
- Standard: 44.1, 48 kHz
- High-Res: 88.2, 96, 176.4, 192 kHz
- Ultra High-Res: 352.8, 384, 705.6 kHz

**Input (DSD):**
- DSD64: 2.8 MHz (2,822,400 Hz)
- DSD128: 5.6 MHz (5,644,800 Hz)
- DSD256: 11.2 MHz (11,289,600 Hz)
- DSD512: 22.5 MHz (22,579,200 Hz)

**Output:**
- Configurable based on profile and settings
- iPod mode: 44.1 or 48 kHz
- ePod/aPlayer: Preserves source or custom target

### File Organization

**iPod Mode:**
```
[iPod Volume]/
└── iPod_Control/
    ├── Music/
    │   ├── F00/
    │   │   ├── ABCD.m4a
    │   │   └── EFGH.m4a
    │   ├── F01/
    │   │   └── IJKL.m4a
    │   ⋮
    │   └── F49/
    └── iTunes/
        ├── iTunesDB      # Database file
        └── LastSync.txt  # Sync timestamp
```

**ePod/aPlayer Mode:**
```
[Device Volume]/
└── Music/
    ├── 01 - Song Name - DTS 5.1_ALAC_16-48.m4a
    ├── 02 - Song Name - DTS 2.0_ALAC_16-48.m4a
    ├── 03 - Album Track - FLAC_24-96.flac
    └── 04 - DSD Track - DSD64_PRESERVED.dsf
```

---

## 🎨 User Interface

### Retro Mode vs. Modern Mode

**Retro Mode (Classic iTunes):**
- Brushed metal gradients
- Classic light appearance
- Nostalgic design elements
- Always light theme

**Modern Mode:**
- Adaptive light/dark appearance
- System theme integration
- Clean, minimal design
- Follows macOS preferences

**Toggle in Settings → Appearance**

### Main Window Layout

```
┌──────────────────────────────────────────────────────┐
│  🎵 Hi-Res iPod Utility                      [  ]  │
│  DSD & Hi-Res PCM → ALAC                            │
├──────────────────────────────────────────────────────┤
│  Convert To: [ CD ] [ BD ] [ SACD ] [ Vinyl ]       │
│  Gain: [═══●═════] +0.0 dB                          │
├──────────────────────────────────────────────────────┤
│  ⚠️  Quality Adjustments:                           │
│   • DSD→PCM conversion to 24-bit/88.2 kHz           │
│   • Resample from 192 kHz → 44.1 kHz                │
├──────────────────────────────────────────────────────┤
│  File List:                                          │
│  ┌────────────────────────────────────────────────┐ │
│  │ ☑ track01.dsf   │ DSD64 │ Warnings │ Ready   │ │
│  │ ☑ track02.flac  │ FLAC  │ None     │ Ready   │ │
│  └────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────┤
│  iPod Sync: [iPod Classic 160GB ▼] [Sync to iPod]  │
└──────────────────────────────────────────────────────┘
```

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's bug fixes, new features, or documentation improvements.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Make your changes** and test thoroughly
4. **Commit your changes:** `git commit -m 'Add amazing feature'`
5. **Push to the branch:** `git push origin feature/amazing-feature`
6. **Open a Pull Request**

### Development Areas

- [ ] **iTunesDB Support** – Full binary format parsing and writing
- [ ] **Additional Profiles** – More device-specific presets
- [ ] **Batch Processing** – Queue management and background conversion
- [ ] **Localization** – Multi-language support (i18n)
- [ ] **Testing** – Unit and integration tests
- [ ] **Documentation** – Code comments and user guides

### Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/hipod.git
cd hipod

# Create a branch
git checkout -b feature/my-feature

# Open in Xcode
open HiPod.xcodeproj

# Make changes and test
# Build with ⌘B, Run with ⌘R
```

---

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for full details.

### MIT License Summary

✅ **Permissions:**
- Commercial use
- Modification
- Distribution
- Private use

⚠️ **Conditions:**
- License and copyright notice required

❌ **Limitations:**
- No liability
- No warranty

---

## 🙏 Acknowledgments

### Technologies
- **[FFmpeg](https://ffmpeg.org/)** – Comprehensive audio/video processing framework
- **[SoXR](https://sourceforge.net/projects/soxr/)** – High-quality sample rate conversion library
- **[SwiftUI](https://developer.apple.com/xcode/swiftui/)** – Modern declarative UI framework

### Inspiration
- **Apple iTunes** – Classic UI design and workflow
- **Audiophile Communities** – r/audiophile, Head-Fi, Hydrogen Audio
- **iPod Enthusiasts** – Keeping classic players alive

### Special Thanks
- The open-source community for continuous support
- Beta testers for valuable feedback
- Contributors who help improve HiPod

---

## 📮 Support

### Get Help
- **📖 Documentation:** [Wiki](https://github.com/yourusername/hipod/wiki)
- **💬 Discussions:** [GitHub Discussions](https://github.com/yourusername/hipod/discussions)
- **🐛 Bug Reports:** [GitHub Issues](https://github.com/yourusername/hipod/issues)
- **✉️ Email:** your.email@example.com

### Report Issues
When reporting bugs, please include:
1. macOS version
2. HiPod version
3. Steps to reproduce
4. Expected vs. actual behavior
5. Console logs (if applicable)

---

## 🗺️ Roadmap

### Version 1.0 (Current)
- [x] Core conversion engine
- [x] iPod/ePod/aPlayer modes
- [x] Multi-stream MKA support
- [x] DSD conversion
- [x] Retro UI mode

### Version 1.1 (Planned)
- [ ] Enhanced iTunesDB support
- [ ] Playlist generation
- [ ] Batch conversion queue
- [ ] Export/import settings

### Version 1.2 (Future)
- [ ] Custom FFmpeg filter chains
- [ ] Network sync support
- [ ] Plug-in architecture
- [ ] Automated update checking

### Version 2.0 (Vision)
- [ ] Apple Music integration
- [ ] Cloud storage sync
- [ ] Mobile companion app
- [ ] Advanced DSP options

---

## ❓ Frequently Asked Questions

### General

**Q: Is HiPod free?**  
A: Yes! HiPod is completely free and open-source under the MIT License.

**Q: Does HiPod work on Apple Silicon Macs?**  
A: Yes! HiPod is a universal binary supporting both Intel and Apple Silicon.

**Q: Will this work with my iPod Nano/Shuffle?**  
A: Currently optimized for iPod Classic/Video/Photo. Nano/Shuffle support is planned.

### Audio Quality

**Q: Is ALAC really lossless?**  
A: Yes! ALAC is mathematically lossless – identical to the source when decoded.

**Q: Does DSD conversion reduce quality?**  
A: DSD→PCM is technically lossy, but HiPod uses high-quality filtering to preserve fidelity.

**Q: What's the best profile for my iPod Classic?**  
A: **CD (16/44.1)** offers guaranteed compatibility. Higher specs may not play on all models.

### File Handling

**Q: Does HiPod modify my original files?**  
A: No! All conversions create new files. Your originals are never touched.

**Q: Where do converted files go?**  
A: By default: `~/Music/HiRes-iPod-[timestamp]/`. You can change this in settings.

**Q: Can I convert Apple Music files?**  
A: No. DRM-protected files from streaming services cannot be converted.

### Device Compatibility

**Q: What devices are supported?**  
A: iPod Classic/Video/Photo, most Hi-Res DAPs, and Android devices with USB storage.

**Q: Do I need iTunes installed?**  
A: No! HiPod works independently without iTunes.

**Q: Can I sync to multiple devices?**  
A: Yes! Scan and select different devices as needed.

### Technical

**Q: Why does HiPod need FFmpeg?**  
A: FFmpeg handles audio decoding, encoding, and processing. It's bundled with the app.

**Q: How long does conversion take?**  
A: Depends on file size and settings. DSD→PCM takes longer than simple format changes.

**Q: Does the retro UI affect performance?**  
A: No! UI styling is purely visual and doesn't impact conversion speed.

---

<div align="center">

## 💝 Made with ❤️ for Audiophiles & iPod Enthusiasts

**Keep the classic alive. Embrace hi-res audio.**

⭐️ **Star this repo** if HiPod helps your workflow!

[🐛 Report Bug](https://github.com/yourusername/hipod/issues) • [✨ Request Feature](https://github.com/yourusername/hipod/issues) • [🤝 Contribute](https://github.com/yourusername/hipod/pulls)

---

**© 2025 HiPod Project | MIT License**

</div>


