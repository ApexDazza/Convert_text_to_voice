# Text to Audiobook Converter for XTTS
# Converts long text into speech files using your local XTTS voices
# 100% offline, no data leaves your machine

param(
    [Parameter(Mandatory=$false)]
    [string]$TextFile,  # Path to text file (or use -Text parameter)
    
    [Parameter(Mandatory=$false)]
    [string]$Text,  # Direct text input
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('cass', 'sophia', 'delaney', 'scarlett', 'heather', 'zendaya', 'australian_female', 'sydney', 'emma')]
    [string]$Voice = "heather",  # Which voice to use (default: heather - 4-star)
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "audiobook_$(Get-Date -Format 'yyyyMMdd_HHmmss').wav",  # Output audio file
    
    [Parameter(Mandatory=$false)]
    [int]$ChunkSize = 500,  # Characters per chunk (safe for XTTS)
    
    [Parameter(Mandatory=$false)]
    [string]$Language = "en",  # Language code
    
    [Parameter(Mandatory=$false)]
    [double]$Speed = 1.0,  # Speech speed (0.5 = slow, 2.0 = fast)
    
    [Parameter(Mandatory=$false)]
    [double]$Temperature = 0.5  # Voice variation (0.1 = consistent, 0.9 = varied)
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Cyan
Write-Host "TEXT TO AUDIOBOOK CONVERTER" -ForegroundColor Cyan
Write-Host "100% Local, Offline Processing - Your Text Never Leaves This Machine" -ForegroundColor Green
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Cyan
Write-Host ""

# Validate input
if (-not $Text -and -not $TextFile) {
    Write-Host "[ERROR] Must provide either -Text or -TextFile parameter" -ForegroundColor Red
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host '  .\text_to_audiobook.ps1 -TextFile "article.txt" -Voice heather' -ForegroundColor Gray
    Write-Host '  .\text_to_audiobook.ps1 -Text "Your text here" -Voice delaney' -ForegroundColor Gray
    exit 1
}

# Load text from file or parameter
if ($TextFile) {
    if (-not (Test-Path $TextFile)) {
        Write-Host "[ERROR] Text file not found: $TextFile" -ForegroundColor Red
        exit 1
    }
    $Text = Get-Content -Path $TextFile -Raw
    Write-Host "[INFO] Loaded text from: $TextFile" -ForegroundColor Cyan
} else {
    Write-Host "[INFO] Using text from parameter" -ForegroundColor Cyan
}

$textLength = $Text.Length
Write-Host "[INFO] Text length: $textLength characters" -ForegroundColor Cyan
Write-Host "[INFO] Voice: $Voice" -ForegroundColor Cyan
Write-Host "[INFO] Output: $OutputFile" -ForegroundColor Cyan
Write-Host ""

# Check if XTTS containers are running
Write-Host "[CHECK] Verifying XTTS services..." -ForegroundColor Yellow
try {
    $xttsStatus = docker ps --filter "name=xtts-server" --format "{{.Status}}"
    $bridgeStatus = docker ps --filter "name=xtts-bridge" --format "{{.Status}}"
    
    if (-not $xttsStatus -or -not $bridgeStatus) {
        Write-Host "[ERROR] XTTS containers not running!" -ForegroundColor Red
        Write-Host "Run: docker start xtts-server xtts-bridge" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [OK] XTTS services are running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not check Docker status: $_" -ForegroundColor Red
    exit 1
}

# Load voice embeddings
Write-Host "`n[LOAD] Loading voice embeddings for '$Voice'..." -ForegroundColor Yellow
$embeddingsFile = "c:\Users\darre\.docker\${Voice}_embeddings.json"

# Try to copy from container if not found locally
if (-not (Test-Path $embeddingsFile)) {
    Write-Host "  Local copy not found, fetching from container..." -ForegroundColor Gray
    try {
        docker cp "xtts-bridge:/app/${Voice}_embeddings.json" $embeddingsFile
    } catch {
        Write-Host "[ERROR] Voice '$Voice' not found in container!" -ForegroundColor Red
        Write-Host "Available voices: cass, sophia, delaney, scarlett, heather, zendaya, australian_female, sydney, emma" -ForegroundColor Yellow
        exit 1
    }
}

$embeddings = Get-Content $embeddingsFile -Raw | ConvertFrom-Json
Write-Host "  [OK] Embeddings loaded" -ForegroundColor Green

# Smart text splitting (respect sentences)
Write-Host "`n[SPLIT] Splitting text into chunks..." -ForegroundColor Yellow

function Split-TextIntoChunks {
    param([string]$InputText, [int]$MaxChunkSize)
    
    $chunks = @()
    $sentences = $InputText -split '(?<=[.!?])\s+'
    $currentChunk = ""
    
    foreach ($sentence in $sentences) {
        $testChunk = if ($currentChunk) { "$currentChunk $sentence" } else { $sentence }
        
        if ($testChunk.Length -le $MaxChunkSize) {
            $currentChunk = $testChunk
        } else {
            # Current chunk is full, save it
            if ($currentChunk) { $chunks += $currentChunk }
            
            # If single sentence is too long, split by words
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

$chunks = Split-TextIntoChunks -InputText $Text -MaxChunkSize $ChunkSize
Write-Host "  [OK] Created $($chunks.Count) chunks" -ForegroundColor Green

# Generate speech for each chunk
Write-Host "`n[GENERATE] Converting text to speech..." -ForegroundColor Yellow
Write-Host "  This will take approximately $([math]::Round($textLength / 100, 1)) minutes" -ForegroundColor Gray
Write-Host ""

$tempDir = Join-Path $env:TEMP "xtts_audiobook_$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Host "[TEMP] Working directory: $tempDir" -ForegroundColor Gray
Write-Host ""

$audioChunks = @()
$chunkNum = 0

foreach ($chunk in $chunks) {
    $chunkNum++
    $progress = [math]::Round(($chunkNum / $chunks.Count) * 100, 1)
    Write-Host "[$chunkNum/$($chunks.Count)] ($progress%) Processing: '$($chunk.Substring(0, [Math]::Min(60, $chunk.Length)))...'" -ForegroundColor Cyan
    
    # Prepare API request
    $body = @{
        text = $chunk
        language = $Language
        gpt_cond_latent = $embeddings.gpt_cond_latent
        speaker_embedding = $embeddings.speaker_embedding
        temperature = $Temperature
        speed = $Speed
        enable_text_splitting = $true
    } | ConvertTo-Json -Depth 10 -Compress
    
    # Ensure UTF-8 encoding
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    
    try {
        # Call XTTS TTS endpoint
        $audioBase64 = Invoke-RestMethod -Uri "http://localhost:8000/tts" `
            -Method POST `
            -ContentType "application/json; charset=utf-8" `
            -Body $bodyBytes `
            -TimeoutSec 120
        
        # Save chunk audio
        $chunkFile = Join-Path $tempDir "chunk_$('{0:D4}' -f $chunkNum).wav"
        $audioBytes = [Convert]::FromBase64String($audioBase64)
        [System.IO.File]::WriteAllBytes($chunkFile, $audioBytes)
        $audioChunks += $chunkFile
        
        Write-Host "    [OK] Generated $([math]::Round($audioBytes.Length / 1KB, 1)) KB" -ForegroundColor Green
        
    } catch {
        Write-Host "    [ERROR] Failed to generate chunk: $_" -ForegroundColor Red
        Write-Host "    Retrying in 5 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Retry once
        try {
            $audioBase64 = Invoke-RestMethod -Uri "http://localhost:8000/tts" `
                -Method POST `
                -ContentType "application/json" `
                -Body $body `
                -TimeoutSec 120
            
            $chunkFile = Join-Path $tempDir "chunk_$('{0:D4}' -f $chunkNum).wav"
            $audioBytes = [Convert]::FromBase64String($audioBase64)
            [System.IO.File]::WriteAllBytes($chunkFile, $audioBytes)
            $audioChunks += $chunkFile
            Write-Host "    [OK] Retry successful" -ForegroundColor Green
        } catch {
            Write-Host "    [ERROR] Retry failed, skipping chunk" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "[MERGE] Combining audio chunks..." -ForegroundColor Yellow

# Check if FFmpeg is available
$ffmpegPath = $null
$ffmpegLocations = @(
    "ffmpeg",  # In PATH
    "C:\ffmpeg\bin\ffmpeg.exe",  # Common install location
    "C:\Program Files\ffmpeg\bin\ffmpeg.exe"
)

foreach ($location in $ffmpegLocations) {
    try {
        $testResult = & $location -version 2>&1
        if ($LASTEXITCODE -eq 0 -or $testResult -match "ffmpeg version") {
            $ffmpegPath = $location
            break
        }
    } catch {
        continue
    }
}

if ($ffmpegPath) {
    Write-Host "  [OK] Using FFmpeg to merge chunks" -ForegroundColor Green
    
    # Create file list for FFmpeg
    $fileListPath = Join-Path $tempDir "filelist.txt"
    $audioChunks | ForEach-Object {
        "file '$($_.Replace('\', '/'))'" | Out-File -Append -Encoding ASCII -FilePath $fileListPath
    }
    
    # Merge using FFmpeg
    & $ffmpegPath -f concat -safe 0 -i $fileListPath -c copy $OutputFile -y 2>&1 | Out-Null
    
    if (Test-Path $OutputFile) {
        Write-Host "  [OK] Audio merged successfully" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] FFmpeg merge failed" -ForegroundColor Red
    }
    
} else {
    Write-Host "  [WARN] FFmpeg not found - will use simple concatenation" -ForegroundColor Yellow
    Write-Host "  For best results, install FFmpeg: https://ffmpeg.org/download.html" -ForegroundColor Gray
    
    # Simple binary concatenation (works for same-format WAV files)
    $combinedBytes = [System.Collections.Generic.List[byte]]::new()
    
    foreach ($chunkFile in $audioChunks) {
        $chunkBytes = [System.IO.File]::ReadAllBytes($chunkFile)
        
        # Skip WAV header except for first chunk
        if ($combinedBytes.Count -eq 0) {
            $combinedBytes.AddRange($chunkBytes)
        } else {
            # Skip 44-byte WAV header on subsequent chunks
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
    Write-Host "  [OK] Chunks concatenated with corrected WAV header" -ForegroundColor Green
}

# Cleanup temp files
Write-Host "`n[CLEANUP] Removing temporary files..." -ForegroundColor Yellow
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "  [OK] Cleanup complete" -ForegroundColor Green

# Final summary
Write-Host ""
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Green
Write-Host "SUCCESS! Audiobook created successfully" -ForegroundColor Green
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Green
Write-Host ""

$outputInfo = Get-Item $OutputFile
Write-Host "Output file: " -NoNewline; Write-Host $OutputFile -ForegroundColor Cyan
Write-Host "File size:   " -NoNewline; Write-Host "$([math]::Round($outputInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "Duration:    " -NoNewline; Write-Host "~$([math]::Round($textLength / 15 / 60, 1)) minutes (estimated)" -ForegroundColor Cyan
Write-Host ""
Write-Host "To transfer to your phone:" -ForegroundColor Yellow
Write-Host "  1. Connect phone via USB" -ForegroundColor Gray
Write-Host "  2. Copy file to phone's Music or Audiobooks folder" -ForegroundColor Gray
Write-Host "  3. Use any audio player app to listen" -ForegroundColor Gray
Write-Host ""
Write-Host "All processing done locally - your text was never sent online!" -ForegroundColor Green
Write-Host ""
