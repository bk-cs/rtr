[scriptblock] $Script = {
    param( [string] $UserDir )
    function Get-UniqueHash ([object] $Obj, [string] $Str) {
        foreach ($I in $Obj) {
            $E = ($Obj | Where-Object { $_.$Str -eq $I.$Str } | Select-Object -Unique).Sha256
            $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
            $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
        }
        $Obj
    }
    [array] $Dir = if ($UserDir) {
        Join-Path $UserDir 'Appdata\Local\Temp'
    } else {
        (Get-WmiObject win32_userprofile | Where-Object { $_.SID -match '^S-1-5-21' }).LocalPath |
            ForEach-Object { Join-Path $_ 'Appdata\Local\Temp' }
        Join-Path $env:SystemRoot 'Temp'
    }
    $Output = $Dir.foreach{
        $Select = @('FullName','Length','CreationTime','LastWriteTime','LastAccessTime')
        Get-ChildItem $_ -Recurse -File -EA 0 | Select-Object $Select | ForEach-Object {
            $_.PSObject.Properties | ForEach-Object { if ($_.Value -is [datetime]) { $_.Value = try {
                $_.Value.ToFileTimeUtc() } catch { $_.Value }}}
            $_
        }
    }
    Get-UniqueHash $Output FullName | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
if ($Param.Username) {
    $UserDir = (Get-WmiObject win32_userprofile | Where-Object {
        $_.LocalPath -match "$([regex]::Escape($Param.Username))$" }).LocalPath
    if (-not $UserDir) {
        throw "No username found matching '$($Param.Username)'."
    }
}
$Start = @{
    FilePath               = 'powershell.exe'
    ArgumentList           = "-Command &{$Script}"
    RedirectStandardOutput = "$Rtr\get_temp_file_$((Get-Date).ToFileTimeUtc()).json"
    PassThru               = $true
}
if ($UserDir) { $Start.ArgumentList += " '$UserDir'" }
Start-Process @Start | Select-Object Id, ProcessName | ForEach-Object {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Json',$Rtr)))
    $_ | ConvertTo-Json -Compress
}