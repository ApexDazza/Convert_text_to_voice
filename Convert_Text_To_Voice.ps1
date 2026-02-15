# Text to Voice Converter - GUI Application
# Version: 1.0
# Created: February 15, 2026
# 100% Offline voice conversion using XTTS

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Continue"

# ============================================================================
# FUNCTIONS
# ============================================================================

function Show-ErrorDialog {
    param([string]$Message, [string]$Title = "Error")
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
}

function Show-InfoDialog {
    param([string]$Message, [string]$Title = "Information")
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Test-XTTSContainers {
    try {
        $xttsStatus = docker ps --filter "name=xtts-server" --format "{{.Status}}" 2>$null
        $bridgeStatus = docker ps --filter "name=xtts-bridge" --format "{{.Status}}" 2>$null
        
        if (-not $xttsStatus -or -not $bridgeStatus) {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

function Get-VoiceEmbeddings {
    param([string]$VoiceName)
    
    $embeddingsFile = "c:\Users\darre\.docker\${VoiceName}_embeddings.json"
    
    # Try to copy from container if not found locally
    if (-not (Test-Path $embeddingsFile)) {
        try {
            docker cp "xtts-bridge:/app/${VoiceName}_embeddings.json" $embeddingsFile 2>$null
        } catch {
            return $null
        }
    }
    
    try {
        $embeddings = Get-Content $embeddingsFile -Raw | ConvertFrom-Json
        return $embeddings
    } catch {
        return $null
    }
}

function Split-TextIntoChunks {
    param([string]$InputText, [int]$MaxChunkSize = 500)
    
    $chunks = @()
    $sentences = $InputText -split '(?<=[.!?])\s+'
    $currentChunk = ""
    
    foreach ($sentence in $sentences) {
        $testChunk = if ($currentChunk) { "$currentChunk $sentence" } else { $sentence }
        
        if ($testChunk.Length -le $MaxChunkSize) {
            $currentChunk = $testChunk
        } else {
            if ($currentChunk) { $chunks += $currentChunk }
            
            if ($sentence.Length -gt $MaxChunkSize) {
                $words = $sentence -split '\s+'
                $subChunk = ""
                foreach ($word in $words) {
                    $testSubChunk = if ($subChunk) { "$subChunk $word" } else { $word }
                    if ($testSubChunk.Length -le $MaxChunkSize) {
                        $subChunk = $testSubChunk
                    } else {
                        if ($subChunk) { $chunks += $subChunk }
                        $subChunk = $word
                    }
                }
                if ($subChunk) { $currentChunk = $subChunk }
            } else {
                $currentChunk = $sentence
            }
        }
    }
    
    if ($currentChunk) { $chunks += $currentChunk }
    return $chunks
}

function Convert-TextToSpeech {
    param(
        [string]$Text,
        [string]$Voice,
        [string]$OutputFile,
        [System.Windows.Forms.Form]$ProgressForm,
        [System.Windows.Forms.Label]$StatusLabel,
        [System.Windows.Forms.ProgressBar]$ProgressBar
    )
    
    try {
        # Update status
        $StatusLabel.Text = "Loading voice embeddings..."
        $ProgressForm.Refresh()
        
        $embeddings = Get-VoiceEmbeddings -VoiceName $Voice
        if (-not $embeddings) {
            throw "Failed to load voice embeddings for '$Voice'"
        }
        
        # Split text into chunks
        $StatusLabel.Text = "Splitting text into chunks..."
        $ProgressForm.Refresh()
        
        $chunks = Split-TextIntoChunks -InputText $Text -MaxChunkSize 500
        $totalChunks = $chunks.Count
        
        $StatusLabel.Text = "Processing $totalChunks text chunks..."
        $ProgressForm.Refresh()
        
        # Create temp directory
        $tempDir = Join-Path $env:TEMP "xtts_conversion_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        $audioChunks = @()
        $chunkNum = 0
        
        # Process each chunk
        foreach ($chunk in $chunks) {
            $chunkNum++
            $progress = [math]::Round(($chunkNum / $totalChunks) * 100)
            
            $StatusLabel.Text = "Processing chunk $chunkNum of $totalChunks ($progress%)"
            $ProgressBar.Value = $progress
            $ProgressForm.Refresh()
            
            # Prepare API request
            $body = @{
                text = $chunk
                language = "en"
                gpt_cond_latent = $embeddings.gpt_cond_latent
                speaker_embedding = $embeddings.speaker_embedding
                temperature = 0.5
                speed = 1.0
                enable_text_splitting = $true
            } | ConvertTo-Json -Depth 10 -Compress
            
            # Ensure UTF-8 encoding
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            
            $retryCount = 0
            $maxRetries = 2
            $success = $false
            
            while (-not $success -and $retryCount -le $maxRetries) {
                try {
                    $audioBase64 = Invoke-RestMethod -Uri "http://localhost:8000/tts" `
                        -Method POST `
                        -ContentType "application/json; charset=utf-8" `
                        -Body $bodyBytes `
                        -TimeoutSec 120
                    
                    $chunkFile = Join-Path $tempDir "chunk_$('{0:D4}' -f $chunkNum).wav"
                    $audioBytes = [Convert]::FromBase64String($audioBase64)
                    [System.IO.File]::WriteAllBytes($chunkFile, $audioBytes)
                    $audioChunks += $chunkFile
                    $success = $true
                    
                } catch {
                    $retryCount++
                    if ($retryCount -le $maxRetries) {
                        $StatusLabel.Text = "Retry $retryCount for chunk $chunkNum..."
                        $ProgressForm.Refresh()
                        Start-Sleep -Seconds 3
                    } else {
                        throw "Failed to process chunk $chunkNum after $maxRetries retries: $_"
                    }
                }
            }
        }
        
        # Merge audio chunks
        $StatusLabel.Text = "Merging audio files..."
        $ProgressBar.Value = 95
        $ProgressForm.Refresh()
        
        # Try FFmpeg first
        $ffmpegPath = $null
        $ffmpegLocations = @("ffmpeg", "C:\ffmpeg\bin\ffmpeg.exe", "C:\Program Files\ffmpeg\bin\ffmpeg.exe")
        
        foreach ($location in $ffmpegLocations) {
            try {
                $testResult = & $location -version 2>&1
                if ($LASTEXITCODE -eq 0 -or $testResult -match "ffmpeg version") {
                    $ffmpegPath = $location
                    break
                }
            } catch { continue }
        }
        
        if ($ffmpegPath) {
            # FFmpeg merge (best quality)
            $fileListPath = Join-Path $tempDir "filelist.txt"
            $audioChunks | ForEach-Object {
                "file '$($_.Replace('\', '/'))'" | Out-File -Append -Encoding ASCII -FilePath $fileListPath
            }
            
            & $ffmpegPath -f concat -safe 0 -i $fileListPath -c copy $OutputFile -y 2>&1 | Out-Null
        } else {
            # Simple concatenation (fallback)
            $combinedBytes = [System.Collections.Generic.List[byte]]::new()
            
            foreach ($chunkFile in $audioChunks) {
                $chunkBytes = [System.IO.File]::ReadAllBytes($chunkFile)
                if ($combinedBytes.Count -eq 0) {
                    $combinedBytes.AddRange($chunkBytes)
                } else {
                    $bytesToAdd = [byte[]]$chunkBytes[44..($chunkBytes.Length - 1)]
                    $combinedBytes.AddRange($bytesToAdd)
                }
            }
            
            # Convert to array and fix WAV header
            $finalBytes = $combinedBytes.ToArray()
            
            # Update RIFF chunk size (bytes 4-7): file size minus 8
            $riffSize = $finalBytes.Length - 8
            $riffSizeBytes = [BitConverter]::GetBytes([uint32]$riffSize)
            [Array]::Copy($riffSizeBytes, 0, $finalBytes, 4, 4)
            
            # Find and update data chunk size (search for 'data' chunk)
            for ($i = 36; $i -lt [Math]::Min(200, $finalBytes.Length - 8); $i++) {
                if ($finalBytes[$i] -eq 0x64 -and $finalBytes[$i+1] -eq 0x61 -and 
                    $finalBytes[$i+2] -eq 0x74 -and $finalBytes[$i+3] -eq 0x61) {
                    # Found 'data' chunk, update size at offset +4
                    $dataSize = $finalBytes.Length - $i - 8
                    $dataSizeBytes = [BitConverter]::GetBytes([uint32]$dataSize)
                    [Array]::Copy($dataSizeBytes, 0, $finalBytes, $i + 4, 4)
                    break
                }
            }
            
            [System.IO.File]::WriteAllBytes($OutputFile, $finalBytes)
        }
        
        # Cleanup
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        $StatusLabel.Text = "Conversion complete!"
        $ProgressBar.Value = 100
        $ProgressForm.Refresh()
        
        return $true
        
    } catch {
        Show-ErrorDialog -Message "Error during conversion:`n`n$_" -Title "Conversion Error"
        return $false
    }
}

# ============================================================================
# MAIN GUI
# ============================================================================

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Text to Voice Converter"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.SystemIcons]::Application

# Title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(560, 30)
$titleLabel.Text = "Convert Text to Speech - 100% Offline"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($titleLabel)

# Voice selection label
$voiceLabel = New-Object System.Windows.Forms.Label
$voiceLabel.Location = New-Object System.Drawing.Point(20, 60)
$voiceLabel.Size = New-Object System.Drawing.Size(100, 20)
$voiceLabel.Text = "Select Voice:"
$form.Controls.Add($voiceLabel)

# Voice dropdown
$voiceDropdown = New-Object System.Windows.Forms.ComboBox
$voiceDropdown.Location = New-Object System.Drawing.Point(120, 58)
$voiceDropdown.Size = New-Object System.Drawing.Size(200, 25)
$voiceDropdown.DropDownStyle = "DropDownList"

# Add voices with ratings
$voices = @(
    @{Name="heather"; Display="Heather (⭐⭐⭐⭐ - Clear, Recommended)"},
    @{Name="delaney"; Display="Delaney (⭐⭐⭐⭐ - Southern US)"},
    @{Name="australian_female"; Display="Australian Female (Dice Game Voice)"},
    @{Name="emma"; Display="Emma (Standard Quality)"},
    @{Name="cass"; Display="Cass (⭐⭐⭐ - Deep Female)"},
    @{Name="zendaya"; Display="Zendaya (⭐⭐ - Some Reverb)"},
    @{Name="sophia"; Display="Sophia (⭐⭐⭐ - High Pitch)"},
    @{Name="scarlett"; Display="Scarlett (⭐ - Whisper)"},
    @{Name="sydney"; Display="Sydney (⭐ - Lower Quality)"}
)

foreach ($voice in $voices) {
    [void]$voiceDropdown.Items.Add($voice.Display)
}
$voiceDropdown.SelectedIndex = 0
$form.Controls.Add($voiceDropdown)

# Text input label
$textLabel = New-Object System.Windows.Forms.Label
$textLabel.Location = New-Object System.Drawing.Point(20, 100)
$textLabel.Size = New-Object System.Drawing.Size(300, 20)
$textLabel.Text = "Enter text to convert:"
$form.Controls.Add($textLabel)

# Text input box
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(20, 125)
$textBox.Size = New-Object System.Drawing.Size(540, 220)
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textBox.Text = "Enter your text here to convert to speech..."
$form.Controls.Add($textBox)

# Character counter
$charCountLabel = New-Object System.Windows.Forms.Label
$charCountLabel.Location = New-Object System.Drawing.Point(20, 350)
$charCountLabel.Size = New-Object System.Drawing.Size(300, 20)
$charCountLabel.Text = "Characters: 0 | Est. time: 0 min"
$charCountLabel.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($charCountLabel)

# Update character count on text change
$textBox.Add_TextChanged({
    $length = $textBox.Text.Length
    $estTime = [math]::Round($length / 100, 1)
    $charCountLabel.Text = "Characters: $length | Est. time: $estTime min"
})

# Output location label
$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Location = New-Object System.Drawing.Point(20, 375)
$outputLabel.Size = New-Object System.Drawing.Size(100, 20)
$outputLabel.Text = "Save to:"
$form.Controls.Add($outputLabel)

# Output file path
$outputPath = New-Object System.Windows.Forms.TextBox
$outputPath.Location = New-Object System.Drawing.Point(120, 373)
$outputPath.Size = New-Object System.Drawing.Size(340, 25)
$outputPath.Text = "X:\Text_To_Voice\Output\voice_$(Get-Date -Format 'yyyyMMdd_HHmmss').wav"
$form.Controls.Add($outputPath)

# Browse button
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(470, 371)
$browseButton.Size = New-Object System.Drawing.Size(90, 28)
$browseButton.Text = "Browse..."
$browseButton.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "WAV Audio Files (*.wav)|*.wav"
    $saveDialog.DefaultExt = "wav"
    $saveDialog.FileName = "voice_$(Get-Date -Format 'yyyyMMdd_HHmmss').wav"
    $saveDialog.InitialDirectory = "X:\Text_To_Voice\Output"
    
    if ($saveDialog.ShowDialog() -eq "OK") {
        $outputPath.Text = $saveDialog.FileName
    }
})
$form.Controls.Add($browseButton)

# Convert button
$convertButton = New-Object System.Windows.Forms.Button
$convertButton.Location = New-Object System.Drawing.Point(200, 415)
$convertButton.Size = New-Object System.Drawing.Size(180, 40)
$convertButton.Text = "Convert to Speech"
$convertButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$convertButton.BackColor = [System.Drawing.Color]::LightGreen
$convertButton.FlatStyle = "Flat"
$convertButton.Add_Click({
    # Validate input
    if ($textBox.Text.Length -lt 10) {
        Show-ErrorDialog -Message "Please enter at least 10 characters of text." -Title "Input Required"
        return
    }
    
    # Check XTTS containers
    if (-not (Test-XTTSContainers)) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "XTTS containers are not running. Would you like to start them?`n`nThis will run: docker start xtts-server xtts-bridge",
            "Start XTTS Services?",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($result -eq "Yes") {
            try {
                docker start xtts-server xtts-bridge 2>&1 | Out-Null
                Start-Sleep -Seconds 5
                Show-InfoDialog -Message "XTTS services started. Please wait 30 seconds for them to initialize, then try again." -Title "Services Started"
            } catch {
                Show-ErrorDialog -Message "Failed to start XTTS containers: $_" -Title "Startup Error"
            }
        }
        return
    }
    
    # Get selected voice
    $selectedIndex = $voiceDropdown.SelectedIndex
    $selectedVoice = $voices[$selectedIndex].Name
    
    # Ensure output directory exists
    $outputDir = Split-Path $outputPath.Text
    if (-not (Test-Path $outputDir)) {
        try {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        } catch {
            Show-ErrorDialog -Message "Cannot create output directory: $outputDir" -Title "Directory Error"
            return
        }
    }
    
    # Create progress form
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "Converting..."
    $progressForm.Size = New-Object System.Drawing.Size(500, 180)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.ControlBox = $false
    $progressForm.TopMost = $true
    
    $progressStatusLabel = New-Object System.Windows.Forms.Label
    $progressStatusLabel.Location = New-Object System.Drawing.Point(20, 20)
    $progressStatusLabel.Size = New-Object System.Drawing.Size(460, 40)
    $progressStatusLabel.Text = "Starting conversion..."
    $progressStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $progressForm.Controls.Add($progressStatusLabel)
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 70)
    $progressBar.Size = New-Object System.Drawing.Size(460, 30)
    $progressBar.Style = "Continuous"
    $progressForm.Controls.Add($progressBar)
    
    $progressInfoLabel = New-Object System.Windows.Forms.Label
    $progressInfoLabel.Location = New-Object System.Drawing.Point(20, 110)
    $progressInfoLabel.Size = New-Object System.Drawing.Size(460, 30)
    $progressInfoLabel.Text = "This may take several minutes depending on text length..."
    $progressInfoLabel.ForeColor = [System.Drawing.Color]::Gray
    $progressForm.Controls.Add($progressInfoLabel)
    
    $progressForm.Show()
    $progressForm.Refresh()
    
    # Disable main form
    $form.Enabled = $false
    
    # Run conversion
    $success = Convert-TextToSpeech -Text $textBox.Text `
                                     -Voice $selectedVoice `
                                     -OutputFile $outputPath.Text `
                                     -ProgressForm $progressForm `
                                     -StatusLabel $progressStatusLabel `
                                     -ProgressBar $progressBar
    
    # Close progress form
    $progressForm.Close()
    $form.Enabled = $true
    
    if ($success) {
        $fileInfo = Get-Item $outputPath.Text
        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        
        $message = "Conversion completed successfully!`n`n" +
                   "Output file: $($outputPath.Text)`n" +
                   "File size: $fileSizeMB MB`n`n" +
                   "Would you like to open the output folder?"
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Conversion Complete",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        if ($result -eq "Yes") {
            Start-Process "explorer.exe" -ArgumentList "/select,`"$($outputPath.Text)`""
        }
    }
})
$form.Controls.Add($convertButton)

# Privacy notice
$privacyLabel = New-Object System.Windows.Forms.Label
$privacyLabel.Location = New-Object System.Drawing.Point(20, 465)
$privacyLabel.Size = New-Object System.Drawing.Size(560, 20)
$privacyLabel.Text = "[SECURE] 100% Local Processing - Your text never leaves this machine"
$privacyLabel.ForeColor = [System.Drawing.Color]::Green
$privacyLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$form.Controls.Add($privacyLabel)

# Show form
[void]$form.ShowDialog()
