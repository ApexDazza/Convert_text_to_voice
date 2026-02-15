# WAV Header Repair Tool
# Fixes WAV files that have incorrect file size in their header
# This happens when multiple WAV chunks are concatenated without updating the header

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = ""
)

if (-not (Test-Path $InputFile)) {
    Write-Host "ERROR: File not found: $InputFile" -ForegroundColor Red
    exit 1
}

if ($OutputFile -eq "") {
    $OutputFile = $InputFile -replace '\.wav$', '_fixed.wav'
}

Write-Host "`nWAV Header Repair Tool" -ForegroundColor Cyan
Write-Host "=====================`n" -ForegroundColor Cyan

# Read the file
$bytes = [System.IO.File]::ReadAllBytes($InputFile)
$fileSize = $bytes.Length

Write-Host "Input file:  $InputFile" -ForegroundColor White
Write-Host "File size:   $fileSize bytes ($([math]::Round($fileSize/1MB,2)) MB)" -ForegroundColor White

# Check current header
$riffHeader = [System.Text.Encoding]::ASCII.GetString($bytes[0..3])
$currentHeaderSize = [BitConverter]::ToUInt32($bytes, 4)

Write-Host "`nCurrent header:" -ForegroundColor Yellow
Write-Host "  RIFF identifier: $riffHeader" -ForegroundColor White
Write-Host "  Size in header:  $($currentHeaderSize + 8) bytes" -ForegroundColor White

if ($riffHeader -ne "RIFF") {
    Write-Host "`nERROR: Not a valid WAV file (missing RIFF header)" -ForegroundColor Red
    exit 1
}

# Check if fix is needed
$correctSize = $fileSize - 8
if ($currentHeaderSize -eq $correctSize) {
    Write-Host "`n✅ Header is already correct - no fix needed!" -ForegroundColor Green
    exit 0
}

Write-Host "`n⚠ Header needs repair!" -ForegroundColor Yellow
Write-Host "  Expected: $($correctSize + 8) bytes" -ForegroundColor White
Write-Host "  Actual:   $($currentHeaderSize + 8) bytes" -ForegroundColor White
Write-Host "  Off by:   $([Math]::Abs($currentHeaderSize - $correctSize)) bytes" -ForegroundColor Red

# Fix the header
Write-Host "`nRepairing header..." -ForegroundColor Cyan

# Update RIFF chunk size (bytes 4-7)
$riffSizeBytes = [BitConverter]::GetBytes([uint32]$correctSize)
[Array]::Copy($riffSizeBytes, 0, $bytes, 4, 4)

# Find and update data chunk size
for ($i = 36; $i -lt [Math]::Min(200, $bytes.Length - 8); $i++) {
    if ($bytes[$i] -eq 0x64 -and $bytes[$i+1] -eq 0x61 -and 
        $bytes[$i+2] -eq 0x74 -and $bytes[$i+3] -eq 0x61) {
        # Found 'data' chunk
        $dataSize = $bytes.Length - $i - 8
        $dataSizeBytes = [BitConverter]::GetBytes([uint32]$dataSize)
        [Array]::Copy($dataSizeBytes, 0, $bytes, $i + 4, 4)
        Write-Host "  Updated RIFF chunk size" -ForegroundColor Green
        Write-Host "  Updated data chunk size" -ForegroundColor Green
        break
    }
}

# Write fixed file
[System.IO.File]::WriteAllBytes($OutputFile, $bytes)

Write-Host "`n✅ SUCCESS: Header repaired!" -ForegroundColor Green
Write-Host "Output file: $OutputFile" -ForegroundColor White

# Verify the fix
$verifyBytes = [System.IO.File]::ReadAllBytes($OutputFile)
$verifyHeaderSize = [BitConverter]::ToUInt32($verifyBytes, 4)
$verifyFileSize = $verifyBytes.Length

Write-Host "`nVerification:" -ForegroundColor Cyan
Write-Host "  File size:   $verifyFileSize bytes" -ForegroundColor White
Write-Host "  Header size: $($verifyHeaderSize + 8) bytes" -ForegroundColor White

if ($verifyHeaderSize -eq ($verifyFileSize - 8)) {
    Write-Host "  Status: ✅ CORRECT" -ForegroundColor Green
    Write-Host "`nThe audio file will now play completely in media players." -ForegroundColor Green
} else {
    Write-Host "  Status: ❌ STILL INCORRECT" -ForegroundColor Red
}
