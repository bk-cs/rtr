$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-ChildItem "$($env:SystemRoot)\Prefetch" *.pf -Recurse -File | Select-Object FullName, Length,
CreationTime, LastWriteTime, LastAccessTime | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
    }
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',((Get-FileHash $_.FullName).Hash.ToLower()))))
    $_
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_prefetch_$(
        (Get-Date).ToFileTimeUtc()).json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }