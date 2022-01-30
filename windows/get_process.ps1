$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-Process -EA 0 | Select-Object Id, Name, StartTime, WorkingSet, CPU, HandleCount, Path |
ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
    }
    if ($Param.Filter) { $_ | Where-Object { $_.Name -match $Param.Filter }} else { $_ }
}
foreach ($Item in $Output) {
    $Copy = ($Output | Where-Object { $_.Path -eq $Item.Path } | Select-Object -Unique).Sha256
    $Hash = if ($Copy) { $Copy } else { try { (Get-FileHash $Item.Path).Hash.ToLower() } catch { $null }}
    $Item.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$Hash)))
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_process.json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }