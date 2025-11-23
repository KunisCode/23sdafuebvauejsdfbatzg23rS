# =============================================
# PowerShell-Skript: Lade und führe test.ps1 aus
# =============================================

# URL zum test.ps1-Skript
$Url = "https://raw.githubusercontent.com/KunisCode/2/main/test.ps1"

# Temporäre Datei
$ScriptPath = "test.ps1"

try {
    Write-Host "Lade Skript von $Url herunter..." -ForegroundColor Cyan
    
    # Invoke-WebRequest durchführen
    $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing
    
    # Inhalt in Datei schreiben
    $Response.Content | Out-File -FilePath $ScriptPath -Encoding UTF8
    
    Write-Host "Skript erfolgreich heruntergeladen als $ScriptPath" -ForegroundColor Green
    
    # Skript ausführen
    Write-Host "Führe $ScriptPath aus..." -ForegroundColor Yellow
    & .\$ScriptPath
    
    # Optional: Datei nach Ausführung löschen
    # Remove-Item $ScriptPath -Force
}
catch {
    Write-Host "Fehler beim Herunterladen oder Ausführen!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "Fertig." -ForegroundColor Cyan
