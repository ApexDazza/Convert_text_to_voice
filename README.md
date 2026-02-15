# Text to Voice Converter

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)
![Privacy](https://img.shields.io/badge/privacy-100%25%20offline-green.svg)

**Convert text to speech using high-quality AI voices - completely offline!**

---

## 🎯 Features

- ✅ **100% Offline Processing** - Your text never leaves your machine
- ✅ **Simple GUI Interface** - Easy to use, no command line needed
- ✅ **9 High-Quality Voices** - Choose from multiple voice options
- ✅ **No Text Limits** - Convert short snippets or long documents
- ✅ **GPU Accelerated** - Fast processing using your RTX GPU
- ✅ **Professional Quality** - 24kHz audio output
- ✅ **Privacy First** - Perfect for confidential documents

---

## 📦 Requirements

### Hardware
- Windows 10/11 (64-bit)
- NVIDIA RTX GPU (tested on RTX 3050)
- 8GB RAM minimum
- 500MB free disk space

### Software
- Docker Desktop with WSL2
- XTTS containers running (xtts-server and xtts-bridge)
- PowerShell 5.1 or later (included with Windows)

---

## 🚀 Quick Start

### Installation

1. **Clone or download this repository:**
   ```bash
   git clone https://github.com/ApexDazza/Convert_text_to_voice.git
   cd Convert_text_to_voice
   ```

2. **Ensure XTTS Docker containers are running:**
   ```powershell
   docker start xtts-server xtts-bridge
   ```
   Wait 30 seconds for services to initialize.

3. **Double-click `Convert_Text_To_Voice.bat` to launch!**

### Usage

1. **Select a voice** from the dropdown menu
2. **Type or paste your text** into the text box
3. **Click "Convert to Speech"**
4. **Wait for processing** (progress bar shows status)
5. **Done!** Audio file is saved and ready to use

---

## 🎤 Available Voices

| Voice | Quality | Characteristics |
|-------|---------|-----------------|
| **Heather** ⭐⭐⭐⭐ | Recommended | Clear, well-spoken US voice |
| **Delaney** ⭐⭐⭐⭐ | High Quality | Southern US accent |
| **Australian Female** | Custom | Dice Game voice sample |
| **Emma** | Standard | General purpose voice |
| **Cass** ⭐⭐⭐ | Good | Deep female voice |
| **Zendaya** ⭐⭐ | Fair | Some reverb present |
| **Sophia** ⭐⭐⭐ | Good | Higher pitch voice |
| **Scarlett** ⭐ | Low | Whisper-style voice |
| **Sydney** ⭐ | Low | Lower quality option |

**Recommended:** Start with **Heather** or **Delaney** for best results.

---

## 📁 Project Structure

```
Text_To_Voice/
├── Convert_Text_To_Voice.bat    # Launcher (double-click this!)
├── Convert_Text_To_Voice.ps1    # Main application
├── README.md                     # This file
├── LICENSE                       # MIT License
├── .gitignore                    # Git ignore rules
└── Output/                       # Generated audio files (auto-created)
```

---

## ⚙️ How It Works

1. **Text Input:** You enter text in the GUI
2. **Smart Chunking:** Text is split into optimal segments
3. **Voice Loading:** Selected voice embeddings are loaded
4. **GPU Processing:** XTTS generates speech using your local GPU
5. **Audio Merging:** Chunks are combined into a single file
6. **Output:** WAV file ready for playback or transfer

**Processing Time:** Approximately 1 minute per 100 characters

---

## 🔒 Privacy & Security

This application is designed with **privacy first**:

- ✅ All processing happens **locally** on your GPU
- ✅ No internet connection required (after setup)
- ✅ No data sent to external servers
- ✅ No telemetry or tracking
- ✅ No logs of your text content

**Perfect for:**
- Confidential business documents
- Personal journals and notes
- Medical or legal documents
- Unpublished manuscripts
- Any sensitive content

---

## 🔧 Troubleshooting

### "XTTS containers are not running"

**Solution:**
```powershell
docker start xtts-server xtts-bridge
```
Wait 30 seconds, then try again.

### "Failed to load voice embeddings"

**Solution:**
Voice files may be missing. Ensure your XTTS containers are properly configured with voice embedding files at:
- `/app/{voice_name}_embeddings.json`

### "Conversion is very slow"

**Normal:** Processing takes ~1 minute per 100 characters. For 1000 characters, expect ~10 minutes.

**If slower:** Check GPU usage:
```powershell
docker exec xtts-server nvidia-smi
```

### Audio has gaps or glitches

**Solution:** Install FFmpeg for seamless audio merging:
1. Download from https://ffmpeg.org/download.html
2. Install to `C:\ffmpeg\`
3. Add `C:\ffmpeg\bin` to Windows PATH
4. Restart the application

---

## 🛠️ Configuration

### Change Default Output Location

Edit line 353 in `Convert_Text_To_Voice.ps1`:
```powershell
$outputPath.Text = "YOUR\CUSTOM\PATH\voice_$(Get-Date -Format 'yyyyMMdd_HHmmss').wav"
```

### Adjust Processing Settings

In the `Convert-TextToSpeech` function, you can modify:
- `temperature` (0.1-0.9): Voice variation (default: 0.5)
- `speed` (0.5-2.0): Speech speed (default: 1.0)
- `MaxChunkSize` (300-800): Characters per chunk (default: 500)

---

## 📊 Performance Tips

### For Best Quality:
- Use **Heather** or **Delaney** voices
- Keep text well-formatted (proper punctuation)
- Spell out abbreviations ("Dr." → "Doctor")

### For Faster Processing:
- Reduce chunk size (300-400 characters)
- Use simpler voices
- Close other GPU-intensive applications

### File Size Estimates:
- 1,000 characters ≈ 0.5 MB
- 10,000 characters ≈ 5 MB
- 100,000 characters ≈ 50 MB

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a pull request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🆘 Support

For issues or questions:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Review XTTS container logs:
   ```powershell
   docker logs xtts-server --tail 50
   docker logs xtts-bridge --tail 50
   ```
3. Open an issue on GitHub

---

## 🙏 Acknowledgments

- **XTTS (Coqui TTS)** - For the amazing text-to-speech model
- **Docker** - For containerization
- **Windows Forms** - For the GUI framework

---

## 📅 Version History

### Version 1.0 (February 15, 2026)
- Initial release
- 9 voice options
- GUI interface
- Batch file launcher
- Progress tracking
- Automatic audio merging
- 100% offline processing

---

**Made with ❤️ for privacy-conscious users**

🔒 **Remember:** Your text stays on your machine. Always.
