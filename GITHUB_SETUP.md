# GitHub Setup Instructions

## Repository Status ✅
- Git initialized in X:\Text_To_Voice
- All files committed
- Remote added: https://github.com/ApexDazza/Convert_text_to_voice.git
- Ready to push!

---

## Push to GitHub

### Option 1: First Time (Create Repository on GitHub)

1. **Go to GitHub:** https://github.com/new
2. **Repository name:** `Convert_text_to_voice`
3. **Description:** "100% offline text to speech converter with GUI"
4. **Public or Private:** Your choice
5. **DO NOT initialize with README** (we already have one)
6. Click "Create repository"

Then push from PowerShell:
```powershell
cd X:\Text_To_Voice
git push -u origin main
```

### Option 2: Repository Already Exists

If you already created the repository on GitHub, just push:
```powershell
cd X:\Text_To_Voice
git push -u origin main
```

---

## Authentication

GitHub will prompt for authentication. You have two options:

### Method 1: Personal Access Token (Recommended)

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Classic"
3. Select scopes: `repo` (full control)
4. Copy the token
5. When prompted for password, use the token instead

### Method 2: GitHub CLI
```powershell
gh auth login
```

---

## Future Updates

After making changes, update GitHub:
```powershell
cd X:\Text_To_Voice
git add .
git commit -m "Your commit message"
git push
```

---

## Verify on GitHub

After pushing, visit:
https://github.com/ApexDazza/Convert_text_to_voice

You should see all your files including:
- README.md (with project description)
- Convert_Text_To_Voice.bat (launcher)
- Convert_Text_To_Voice.ps1 (main program)
- LICENSE
- QUICKSTART.md
- Output folder structure

---

## Clone to Another Computer

To use on another machine:
```powershell
git clone https://github.com/ApexDazza/Convert_text_to_voice.git X:\Text_To_Voice
cd X:\Text_To_Voice
```

Then ensure XTTS Docker containers are set up and running!
