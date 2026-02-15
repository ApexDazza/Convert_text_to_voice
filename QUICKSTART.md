# Quick Start Guide

## First Time Setup

1. **Ensure Docker is running:**
   - Open Docker Desktop
   - Wait for it to fully start

2. **Start XTTS containers:**
   ```powershell
   docker start xtts-server xtts-bridge
   ```
   Wait 30 seconds for initialization.

3. **Launch the application:**
   - Double-click `Convert_Text_To_Voice.bat`
   - The GUI window will open

4. **Convert your first text:**
   - Select a voice (try "Heather" first)
   - Enter some text (at least 10 characters)
   - Click "Convert to Speech"
   - Wait for progress bar to complete
   - Find your audio file in the Output folder!

## Tips

- **Character count:** Shows estimated processing time
- **Browse button:** Choose where to save the file
- **Progress bar:** Shows real-time conversion progress
- **First conversion:** May take longer as models load

## Troubleshooting

If you see "XTTS containers not running":
- Click "Yes" to auto-start them
- Wait 30 seconds
- Try converting again

If conversion fails:
- Check Docker Desktop is running
- Restart XTTS containers:
  ```powershell
  docker restart xtts-server xtts-bridge
  ```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Experiment with different voices
- Try converting longer texts

---

**Privacy Note:** All processing happens on your local machine. Your text is never sent anywhere!
