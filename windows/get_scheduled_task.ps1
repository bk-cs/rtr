$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_scheduled_task_$((Get-Date).ToFileTimeUtc()).json"
$Tasks = Join-Path $env:SystemRoot '\system32\Tasks'
$Output = foreach ($Task in (Get-ChildItem -Path $Tasks -File -Recurse -EA 0 | Select-Object Name, FullName)) {
    foreach ($Xml in ([xml] (Get-Content $Task.FullName))) {
        [PSCustomObject] @{
            Name      = $Task.Name
            UserId    = $Xml.Task.Principals.Principal.UserId
            Author    = $Xml.Task.RegistrationInfo.Author
            Enabled   = $Xml.Task.Settings.Enabled
            Command   = $Xml.Task.Actions.Exec.Command
            Arguments = $Xml.Task.Actions.Exec.Arguments
        } | ForEach-Object {
            if ($Param.Filter) {
                $_ | Where-Object { $_.Name -match $Param.Filter -or $_.Command -match $Param.Filter }
            } else {
                $_
            }
        }
    }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }