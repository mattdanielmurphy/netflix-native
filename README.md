# Netflix Native for macOS

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Netflix Native Icon" />
</p>

<p align="center">
  <strong>An ultra-lightweight, native macOS 4K Netflix player with Apple Silicon HEVC hardware acceleration and FairPlay DRM.</strong>
</p>

---

## ⚠️ The 4K Netflix on Mac Requirement

> [!IMPORTANT]
> **Did you know?** On macOS, third-party browsers like **Google Chrome, Mozilla Firefox, Brave, and Microsoft Edge cannot stream Netflix in 4K** (they are restricted to 1080p via Widevine L3 DRM).
>
> The **only** way to stream Netflix in **True 4K UHD (2160p) with HEVC and HDR** on a Mac is through Apple's native **WebKit** engine backed by Apple **FairPlay Streaming DRM** (`com.apple.fps_3_0`).

While Safari supports 4K, using Safari tabs or Safari's *"Add to Dock"* web app feature comes with annoying limitations:
- ❌ Hitting Spacebar triggers the macOS system error alert sound ("bonk").
- ❌ Captchas and tracking beacons spawn unwanted external tabs in your default browser.
- ❌ Window controls and keyboard navigation often lose focus.
- ❌ Browser UI chrome, tabs, and bookmark bars clutter the viewing experience.

**Netflix Native** solves all of this: a standalone, clean native macOS application that unlocks full 4K HEVC playback with none of the browser friction.

---

## ✨ Features

- 🎬 **True 4K UHD & HDR**: Full 2160p stream authorization via Apple FairPlay 3.0 and HEVC hardware decode pipeline (~15 Mbps bitrate tier).
- ⚡ **Ultra-Lightweight**: Built with pure Swift, AppKit, and WebKit. No Electron, no Chromium bloat, and minimal RAM/battery consumption.
- ⌨️ **Native Media Controls**: Spacebar play/pause without macOS error alert sounds, arrow key seeking, `F` for fullscreen, `M` to mute, and `S` to skip intro.
- 🛡️ **Isolated Web View**: Strict navigation policy prevents background reCAPTCHA beacons and login redirects from launching external browser windows.
- 🎨 **macOS Design**: Dark appearance, frameless title bar, window position autosave, and custom Big Sur-style app icon.
- 🔋 **Smart Sleep Management**: Holds macOS system power assertions during active video playback and pauses smoothly on system sleep.

---

## 🚀 Quick Install (1-Line Build & Install)

Open **Terminal** (press `Cmd + Space`, type `Terminal`, and hit `Enter`), then paste:

```bash
git clone https://github.com/mattdanielmurphy/netflix-native.git && cd netflix-native && bash bin/build_and_bundle.sh
```

That's it! The script will compile the native binary, package the app, and install **`Netflix.app`** directly into your **`/Applications`** folder. You can now launch it from Spotlight, Launchpad, or your Dock.

### Or Run via Bun / Terminal

If you prefer building and launching from source:

```bash
# Build and launch
bun dev

# Or using plain bash
bash bin/build_and_bundle.sh && open /Applications/Netflix.app
```

---

## 🔍 How to Verify 4K Playback

1. Open **Netflix Native** and play any 4K-supported title (e.g., *Better Call Saul*, *Stranger Things*, *Our Planet*).
2. Press `Ctrl + Option + Shift + D` to bring up Netflix's diagnostic stream overlay.
3. Verify the following metrics:
   - **`KeyStatus`**: Contains `..., 540, 1080, 2160, usable` (confirming the 4K decryption key is active).
   - **`Video Track Codec`**: `video/mp4;codecs=hev1... (hevc, prk)` (hardware HEVC decoding).
   - **`Buffering bitrate`**: Ramps up to `~14,871 kbps` (the top 4K UHD bitrate ladder).

*(Note: Netflix uses adaptive streaming; when playback begins, it buffers the initial few seconds at 1080p before automatically ramping to 2160p within 10–15 seconds).*

---

## 📋 Requirements

- **Operating System**: macOS 13.0 (Ventura) or newer.
- **Hardware**: Apple Silicon (M1, M2, M3, M4, Pro/Max/Ultra) or Intel Mac with Apple T2 Security Chip.
- **Subscription**: Netflix Premium Plan (required by Netflix for 4K UHD streaming).

---

## 🛠️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Space` / `K` | Play / Pause |
| `←` / `→` | Seek Backward / Forward 10s |
| `↑` / `↓` | Volume Up / Down |
| `F` / `Cmd + Ctrl + F` | Toggle Fullscreen |
| `M` | Mute / Unmute Audio |
| `S` | Skip Intro / Recap |
| `Cmd + R` | Reload Page |
| `Cmd + Shift + H` | Go to Netflix Home |
| `Ctrl + Opt + Shift + D` | Toggle Stream Diagnostics Overlay |

---

## 📄 License

MIT License. Designed for personal use on macOS. Netflix is a registered trademark of Netflix, Inc.
