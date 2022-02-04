function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = foreach ($Value in (Get-ChildItem "Registry::\HKEY_USERS" -EA 0 | Where-Object {
$_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName) {
    Get-ChildItem "Registry::\HKEY_USERS\$Value\Network" -EA 0 | ForEach-Object {
        [PSCustomObject] @{
            Share      = $_.PSChildName
            RemotePath = $_.GetValue('RemotePath')
            UserName   = (Get-WmiObject Win32_UserAccount | Where-Object { $_.SID -eq $Value }).Name
            Sid        = $Value
        }
    }
}
Write-Output $Output $Param "get_remote_share_$((Get-Date).ToFileTimeUtc()).json"