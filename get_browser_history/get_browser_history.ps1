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
$Out = foreach ($User in (gwmi Win32_UserProfile | ? {
$_.localpath -notmatch 'Windows' }).localpath) {
    foreach ($Path in @('AppData\Local\Google\Chrome\User Data\Default\History',
    'AppData\Local\Microsoft\Edge\User Data\Default\History')) {
        $History = Join-Path $User $Path
        if (Test-Path $History) {
            $Domain = '(htt(p|ps))://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
            gc $History | Select-String -AllMatches $Domain |
            % { ($_.Matches).Value } | sort -Unique | % {
                if ($_ -match $Search) {
                    [PSCustomObject] @{
                        Username = $User | Split-Path -Leaf
                        Browser  = if ($History -match 'Chrome') { 'Chrome' } else { 'Edge' }
                        Domain   = $_
                    }
                }
            }
        }
    }
}
if ($Param.Filter) {
    $Out = $Out | ? { $_.Domain -match $Param.Filter }
}
output $Out $Param "get_browser_history_$((Get-Date).ToFileTimeUtc()).json"