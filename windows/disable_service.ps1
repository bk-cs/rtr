function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
if (-not $Param.Name) {
    throw "Missing required parameter 'Name'."
}
$Service = Get-Service | Where-Object { $_.Name -eq $Param.Name }
if (-not $Service) {
    throw "No results for service '$($Param.Name)'."
}
if ($Service.StartType) {
    $Service | Set-Service -StartupType Disabled
}
if ($Service.Status -ne 'Stopped') {
    $Service | Set-Service -Status Stopped
}
$Output = Get-Service -Name $Param.Name | Select-Object Name, Status, StartType
Write-Output $Output $Param "$Rtr\disable_service_$((Get-Date).ToFileTimeUtc()).json"