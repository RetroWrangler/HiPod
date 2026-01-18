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

## 📦 Getting Started
```bash
# 1. Clone
$ git clone https://github.com/yourusername/hipod.git
$ cd hipod

# 2. Open in Xcode
# (Xcode 15+, macOS 14+ recommended)

# 3. Build and Run

