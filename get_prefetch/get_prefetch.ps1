function Get-UniqueHash ([object] $Obj, [string] $Str) {
    foreach ($I in $Obj) {
        $E = ($Obj | Where-Object { $_.$Str -eq $I.$Str } | Select-Object -Unique).Sha256
        $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
        $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
    }
    $Obj
}
function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-ChildItem "$($env:SystemRoot)\Prefetch" *.pf -Recurse -File | Select-Object FullName, Length,
CreationTime, LastWriteTime, LastAccessTime | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
    }
    $_
}
$Output = Get-UniqueHash $Output FullName
Write-Output $Output $Param "get_prefetch_$((Get-Date).ToFileTimeUtc()).json"