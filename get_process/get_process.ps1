function hash ([object] $Obj, [string] $Str) {
    foreach ($I in $Obj) {
        $E = ($Obj | ? { $_.$Str -eq $I.$Str } | select -Unique).Sha256
        $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
        $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
    }
    $Obj
}
function output ([object] $Obj, [object] $Param, [string] $Json) {
    if ($Obj -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr -PathType Container) -eq $false) { ni $Rtr -ItemType Directory }
        $O = @{ tags = @{ json = $Json; script = $Json -replace '_\d+\.json$','.ps1';
            host = [System.Net.Dns]::GetHostName() }}
        $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-' +
            '7058-48c9-a204-725362b67639}\Default') 2>$null
        if ($R) {
            $O.tags['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $O.tags['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        $Evt = $Obj | % {
            $Att = @{}
            $_.PSObject.Properties | % { $Att[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $Att }
        }
        if (($Evt | measure).Count -eq 1) {
            $O['events'] = @($Evt)
            $O | ConvertTo-Json -Depth 8 -Compress >> (Join-Path $Rtr $Json)
        } elseif (($Evt | measure).Count -gt 1) {
            for ($i = 0; $i -lt ($Evt | measure).Count; $i += 200) {
                $C = $O.Clone()
                $C['events'] = $Evt[$i..($i + 199)]
                $C | ConvertTo-Json -Depth 8 -Compress >> (Join-Path $Rtr $Json)
            }
        }
    }
    $Obj | ConvertTo-Json -Compress
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Out = Get-Process -EA 0 | select Id, Name, StartTime, WorkingSet, CPU, HandleCount, Path |
% {
    $_.PSObject.Properties | % {
        if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
    }
    if ($Param.Filter) { $_ | ? { $_.Name -match $Param.Filter }} else { $_ }
}
$Out = hash $Out Path
output $Out $Param "get_process_$((Get-Date).ToFileTimeUtc()).json"