function grk ([string] $Str) {
    $Obj = foreach ($N in (gci 'Registry::\').PSChildName) {
        if ($N -eq 'HKEY_USERS') {
            foreach ($V in (gci "Registry::\$N" -EA 0 | ? {
            $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName) {
                if (Test-Path "Registry::\$N\$V\$Str") { gci "Registry::\$N\$V\$Str" -EA 0 }
            }
        } elseif (Test-Path "Registry::\$N\$Str") {
            gci "Registry::\$N\$Str" -EA 0
        }
    }
    $Obj | % {
        $I = [PSCustomObject] @{}
        foreach ($P in $_.Property) {
            $I.PSObject.Properties.Add((New-Object PSNoteProperty($P,($_.GetValue($P)))))
        }
        $I
    }
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
        $Evt = @($Obj).foreach{
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
$Out = @('Microsoft\Windows\CurrentVersion\Uninstall',
'Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall').foreach{
    grk "Software\$_" | ? { $_.DisplayName -and $_.DisplayVersion -and $_.Publisher } | select DisplayName,
    DisplayVersion, Publisher, InstallLocation | % {
        if ($Param.Filter) { $_ | ? { $_.DisplayName -match $Param.Filter }} else { $_ }
    }
}
output $Out $Param "get_application_$((Get-Date).ToFileTimeUtc()).json"