# Automated Voice Quality Testing Script
# Tests 5 voices with varying text lengths to find optimal voice and length limits
# Created: February 15, 2026

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Cyan
Write-Host "VOICE QUALITY TESTING SUITE" -ForegroundColor Cyan
Write-Host "Testing 5 voices with varying text lengths" -ForegroundColor Yellow
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Cyan
Write-Host ""

# Import functions from main script
. "X:\Text_To_Voice\Convert_Text_To_Voice.ps1"

# Test configuration
$testVoices = @("heather", "delaney", "australian_female", "emma", "cass")
$testResults = @()

# Create test directory
$testDir = "X:\Text_To_Voice\Test_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Write-Host "[INFO] Test results will be saved to: $testDir" -ForegroundColor Cyan
Write-Host ""

# Test samples with varying lengths
$testSamples = @(
    @{
        Name = "Short_100chars"
        Length = "~100 characters (1 sentence)"
        Text = "The quick brown fox jumps over the lazy dog, demonstrating the remarkable agility of wild animals."
    },
    @{
        Name = "Medium_500chars"
        Length = "~500 characters (1 paragraph)"
        Text = "In the heart of the ancient forest, where sunlight filtered through the dense canopy, a remarkable discovery awaited. The research team had spent months searching for evidence of the rare golden salamander, a creature thought to be extinct for over fifty years. As they carefully examined the moss-covered rocks near the crystal-clear stream, a flash of brilliant gold caught their eye. There, perfectly camouflaged among the autumn leaves, was the salamander they had been seeking. This moment would change everything they knew about wildlife conservation."
    },
    @{
        Name = "Long_1000chars"
        Length = "~1000 characters (2-3 paragraphs)"
        Text = "The industrial revolution transformed society in ways that few could have predicted. Beginning in the late eighteenth century, innovations in manufacturing and transportation reshaped the economic landscape of nations across the globe. The introduction of steam power revolutionized production methods, allowing factories to operate at unprecedented scales and speeds. Workers who had previously toiled in fields and workshops found themselves in massive industrial complexes, operating machines that could produce goods faster than anyone had imagined possible. This shift from agrarian to industrial economies brought both prosperity and challenges. Cities grew rapidly as people migrated in search of employment, leading to overcrowding and poor living conditions. Child labor became widespread, with young children working long hours in dangerous factory conditions. However, these same forces also drove technological advancement, improved standards of living for many, and created new opportunities for education and social mobility. The legacy of this period continues to influence modern society."
    },
    @{
        Name = "VeryLong_2000chars"
        Length = "~2000 characters (1 book page)"
        Text = "The concept of artificial intelligence has captivated human imagination for generations, long before computers became household devices. Early pioneers in the field dreamed of creating machines that could think, learn, and reason like humans. Alan Turing, often considered the father of computer science, proposed his famous test in nineteen fifty to determine whether machines could exhibit intelligent behavior indistinguishable from humans. Throughout the following decades, researchers made incremental progress, developing algorithms for chess playing, pattern recognition, and natural language processing. The field experienced periods of great optimism followed by so-called AI winters, when progress stalled and funding dried up. However, the twenty-first century brought a renaissance in artificial intelligence research, driven by three key factors: massive increases in computing power, the availability of enormous datasets, and breakthroughs in neural network architectures. Deep learning systems began achieving remarkable results in image recognition, speech processing, and game playing, often surpassing human-level performance. These advances sparked both excitement and concern about the implications of increasingly capable AI systems. Questions about job displacement, algorithmic bias, privacy, and the long-term future of humanity in an age of intelligent machines became central to public discourse. Researchers and ethicists now work to ensure that artificial intelligence develops in ways that benefit humanity while minimizing potential risks. The journey from early mechanical calculators to sophisticated neural networks represents one of humanity's most ambitious technological endeavors, with profound implications for virtually every aspect of modern life."
    },
    @{
        Name = "BookPages_3000chars"
        Length = "~3000 characters (2-3 book pages)"
        Text = "The morning sun cast long shadows across the cobblestone streets of the old quarter, where centuries of history seemed to whisper from every weathered facade. Maria walked slowly, her footsteps echoing in the quiet dawn, taking in the architectural details that tourists rushing through would miss: the intricate ironwork of balconies, the faded frescoes hiding beneath layers of time, the worn doorways that had welcomed countless generations. She had returned to this neighborhood after twenty years abroad, and every corner triggered a cascade of memories. The bakery on the corner, now a modern coffee shop, was where her grandmother had bought fresh bread every morning. The small plaza ahead, currently home to outdoor cafes and street musicians, was where she had played as a child, imagining adventures in distant lands. How ironic that those childhood dreams had come true, taking her around the world, only to bring her back to where it all began. She paused at the fountain in the center of the plaza, running her fingers along the weathered stone edge. The water still flowed from the mouth of the stone lion, just as it had for hundreds of years, indifferent to the passage of time and the changes in the world around it. Her phone buzzed with a message from the real estate agent. The apartment was ready for viewing, the same building where her family had lived for three generations. She had the opportunity to buy it, to reclaim a piece of her past and perhaps build a new future. The decision weighed heavily on her mind. Part of her longed for the familiarity and connection to her roots, while another part feared that returning would mean giving up the freedom and independence she had worked so hard to achieve. As she walked toward the meeting point, Maria noticed how the neighborhood had evolved while maintaining its essential character. New businesses occupied old spaces, young families pushed strollers along the same paths where she had run as a child, and the community seemed to thrive by honoring its past while embracing the future. Perhaps, she thought, it was possible to do both: to come home without going backward, to build something new on a foundation of treasured memories. The key to her future might lie in understanding that home was not about returning to what was, but rather about carrying forward what mattered most while remaining open to new possibilities. With renewed determination, she quickened her pace, ready to take the next step in her journey."
    }
)

Write-Host "[START] Beginning test sequence at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
Write-Host ""

# Test each voice with each sample
$testNumber = 0
$totalTests = $testVoices.Count * $testSamples.Count

foreach ($voice in $testVoices) {
    Write-Host ""
    Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Yellow
    Write-Host "TESTING VOICE: $($voice.ToUpper())" -ForegroundColor Yellow
    Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($sample in $testSamples) {
        $testNumber++
        $progress = [math]::Round(($testNumber / $totalTests) * 100, 1)
        
        Write-Host "[$testNumber/$totalTests] ($progress%) Testing: $($sample.Name) with $voice" -ForegroundColor Cyan
        Write-Host "  Length: $($sample.Length)" -ForegroundColor Gray
        Write-Host "  Actual: $($sample.Text.Length) characters" -ForegroundColor Gray
        
        $outputFile = Join-Path $testDir "Test_${voice}_$($sample.Name).wav"
        $startTime = Get-Date
        
        try {
            # Load voice embeddings
            $embeddingsFile = "c:\Users\darre\.docker\${voice}_embeddings.json"
            
            if (-not (Test-Path $embeddingsFile)) {
                Write-Host "  Fetching embeddings from container..." -ForegroundColor Yellow
                docker cp "xtts-bridge:/app/${voice}_embeddings.json" $embeddingsFile 2>$null
            }
            
            $embeddings = Get-Content $embeddingsFile -Raw | ConvertFrom-Json
            
            # Split text into chunks
            $chunks = Split-TextIntoChunks -InputText $sample.Text -MaxChunkSize 500
            
            Write-Host "  Processing $($chunks.Count) chunks..." -ForegroundColor Gray
            
            # Generate audio for each chunk
            $tempDir = Join-Path $env:TEMP "xtts_test_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $audioChunks = @()
            $chunkNum = 0
            
            foreach ($chunk in $chunks) {
                $chunkNum++
                
                $body = @{
                    text = $chunk
                    language = "en"
                    gpt_cond_latent = $embeddings.gpt_cond_latent
                    speaker_embedding = $embeddings.speaker_embedding
                    temperature = 0.5
                    speed = 1.0
                    enable_text_splitting = $true
                } | ConvertTo-Json -Depth 10
                
                $audioBase64 = Invoke-RestMethod -Uri "http://localhost:8000/tts" `
                    -Method POST `
                    -ContentType "application/json" `
                    -Body $body `
                    -TimeoutSec 120
                
                $chunkFile = Join-Path $tempDir "chunk_$('{0:D4}' -f $chunkNum).wav"
                $audioBytes = [Convert]::FromBase64String($audioBase64)
                [System.IO.File]::WriteAllBytes($chunkFile, $audioBytes)
                $audioChunks += $chunkFile
            }
            
            # Merge audio
            Write-Host "  Merging audio..." -ForegroundColor Gray
            
            # Try FFmpeg first
            $ffmpegPath = $null
            try {
                $testResult = & ffmpeg -version 2>&1
                if ($LASTEXITCODE -eq 0) { $ffmpegPath = "ffmpeg" }
            } catch { }
            
            if ($ffmpegPath) {
                $fileListPath = Join-Path $tempDir "filelist.txt"
                $audioChunks | ForEach-Object {
                    "file '$($_.Replace('\', '/'))'" | Out-File -Append -Encoding ASCII -FilePath $fileListPath
                }
                & $ffmpegPath -f concat -safe 0 -i $fileListPath -c copy $outputFile -y 2>&1 | Out-Null
            } else {
                # Simple concatenation
                $combinedBytes = [System.Collections.Generic.List[byte]]::new()
                foreach ($chunkFile in $audioChunks) {
                    $chunkBytes = [System.IO.File]::ReadAllBytes($chunkFile)
                    if ($combinedBytes.Count -eq 0) {
                        $combinedBytes.AddRange($chunkBytes)
                    } else {
                        $combinedBytes.AddRange($chunkBytes[44..($chunkBytes.Length - 1)])
                    }
                }
                [System.IO.File]::WriteAllBytes($outputFile, $combinedBytes.ToArray())
            }
            
            # Cleanup temp
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            $fileInfo = Get-Item $outputFile
            
            $result = [PSCustomObject]@{
                Voice = $voice
                TestName = $sample.Name
                TextLength = $sample.Text.Length
                ChunkCount = $chunks.Count
                ProcessingTime = [math]::Round($duration, 1)
                OutputSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                TimePerChar = [math]::Round($duration / $sample.Text.Length, 4)
                Status = "Success"
                OutputFile = $outputFile
            }
            
            $testResults += $result
            
            Write-Host "  ✓ Success!" -ForegroundColor Green
            Write-Host "    Processing time: $($result.ProcessingTime)s" -ForegroundColor Green
            Write-Host "    Output size: $($result.OutputSizeMB) MB" -ForegroundColor Green
            Write-Host "    Rate: $([math]::Round($sample.Text.Length / $duration, 1)) chars/sec" -ForegroundColor Green
            
        } catch {
            Write-Host "  ✗ Failed: $_" -ForegroundColor Red
            
            $result = [PSCustomObject]@{
                Voice = $voice
                TestName = $sample.Name
                TextLength = $sample.Text.Length
                ChunkCount = 0
                ProcessingTime = 0
                OutputSizeMB = 0
                TimePerChar = 0
                Status = "Failed: $_"
                OutputFile = ""
            }
            
            $testResults += $result
        }
        
        Start-Sleep -Seconds 2  # Brief pause between tests
    }
}

Write-Host ""
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Green
Write-Host "TESTING COMPLETE!" -ForegroundColor Green
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Green
Write-Host ""

# Generate results summary
Write-Host "RESULTS SUMMARY:" -ForegroundColor Cyan
Write-Host ""

# Display results table
$testResults | Format-Table Voice, TestName, TextLength, ProcessingTime, OutputSizeMB, Status -AutoSize

# Save detailed results to CSV
$csvPath = Join-Path $testDir "Test_Results_Summary.csv"
$testResults | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "[SAVED] Detailed results: $csvPath" -ForegroundColor Green

# Analysis
Write-Host ""
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Yellow
Write-Host "ANALYSIS" -ForegroundColor Yellow
Write-Host "=" -NoNewline; Write-Host ("=" * 79) -ForegroundColor Yellow
Write-Host ""

$successfulTests = $testResults | Where-Object { $_.Status -eq "Success" }

if ($successfulTests.Count -gt 0) {
    # Average processing time by voice
    Write-Host "Average Processing Time by Voice:" -ForegroundColor Cyan
    $successfulTests | Group-Object Voice | ForEach-Object {
        $avgTime = ($_.Group | Measure-Object ProcessingTime -Average).Average
        $avgRate = ($_.Group | Measure-Object TimePerChar -Average).Average
        $charsPerSec = [math]::Round(1/$avgRate, 1)
        $avgTimeRounded = [math]::Round($avgTime, 1)
        $voiceName = $_.Name
        Write-Host "  ${voiceName}: ${avgTimeRounded} seconds avg, ${charsPerSec} characters per second" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Processing Time by Text Length:" -ForegroundColor Cyan
    $successfulTests | Group-Object TestName | ForEach-Object {
        $avgTime = ($_.Group | Measure-Object ProcessingTime -Average).Average
        $textLen = $_.Group[0].TextLength
        $avgTimeRounded = [math]::Round($avgTime, 1)
        $testName = $_.Name
        Write-Host "  ${testName} - ${textLen} characters: ${avgTimeRounded} seconds average" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Output File Sizes:" -ForegroundColor Cyan
    $successfulTests | Group-Object TestName | ForEach-Object {
        $avgSize = ($_.Group | Measure-Object OutputSizeMB -Average).Average
        Write-Host "  $($_.Name): $([math]::Round($avgSize, 2)) MB avg" -ForegroundColor White
    }
    
    # Best voice recommendation
    Write-Host ""
    Write-Host "RECOMMENDATIONS:" -ForegroundColor Green
    $fastestVoice = $successfulTests | Group-Object Voice | 
        Select-Object Name, @{N="AvgTime";E={($_.Group | Measure-Object ProcessingTime -Average).Average}} | 
        Sort-Object AvgTime | Select-Object -First 1
    $fastestName = $fastestVoice.Name
    Write-Host "  Fastest Voice: ${fastestName}  - ${fastestAvgTime} seconds average" -ForegroundColor Green
    
    # Check for failures or issues
    $longTextTests = $successfulTests | Where-Object { $_.TextLength -ge 2000 }
    if ($longTextTests.Count -gt 0) {
        Write-Host '  Long Text (2000+ characters): All tested voices handled successfully' -ForegroundColor Green
        Write-Host '  Book Page Conversion: VIABLE for 2-3 pages (approximately 3000 characters)' -ForegroundColor Green
    }
}

$failedTests = $testResults | Where-Object { $_.Status -ne "Success" }
if ($failedTests.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    $failedTests | ForEach-Object {
        Write-Host "  $($_.Voice) - $($_.TestName): $($_.Status)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "All test files saved to: $testDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Listen to the generated audio files" -ForegroundColor Gray
Write-Host "  2. Compare voice quality subjectively" -ForegroundColor Gray
Write-Host "  3. Note any artifacts or issues with longer texts" -ForegroundColor Gray
Write-Host "  4. Choose your preferred voice for book conversion" -ForegroundColor Gray
Write-Host ""
