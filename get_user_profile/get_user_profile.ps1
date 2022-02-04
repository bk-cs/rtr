function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-WmiObject win32_userprofile | Where-Object { $_.SID -match '^S-1-5-21' } | Select-Object Sid,
    LocalPath, RoamingPath, RoamingConfigured, LastUseTime
Write-Output $Output $Param  "get_user_profile_$((Get-Date).ToFileTimeUtc()).json"