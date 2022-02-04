function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-WmiObject Win32_Service -EA 0 | Select-Object ProcessId, Name, PathName | ForEach-Object {
    if ($Param.Filter) {
        $_ | Where-Object { $_.Name -match $Param.Filter -or $_.PathName -match $Param.Filter }
    } else {
        $_
    }
}
Write-Output $Output $Param "get_service_$((Get-Date).ToFileTimeUtc()).json"