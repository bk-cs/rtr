[scriptblock] $Script = {
    param( [string] $Json, [string] $UserDir )
    function hash ([object] $Obj, [string] $Str) {
        foreach ($I in $Obj) {
            $E = ($Obj | ? { $_.$Str -eq $I.$Str } | select -Unique).Sha256
            $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
            $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
        }
        $Obj
    }
    [array] $Dir = if ($UserDir) {
        Join-Path $UserDir 'Appdata\Local\Temp'
    } else {
        (gwmi win32_userprofile | ? { $_.SID -match '^S-1-5-21' }).LocalPath | % {
            Join-Path $_ 'Appdata\Local\Temp' }
        Join-Path $env:SystemRoot 'Temp'
    }
    $Obj = $Dir.foreach{
        $Select = @('FullName','Length','CreationTime','LastWriteTime','LastAccessTime')
        gci $_ -Recurse -File -EA 0 | select $Select | % {
            $_.PSObject.Properties | % {
                if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
            }
            $_
        }
    }
    $Obj = hash $Obj FullName
    $O = @{ tags = @{ json = $Json; script = $Json -replace '_\d+\.json$','.ps1';
        host = [System.Net.Dns]::GetHostName() }}
    $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058' +
        '-48c9-a204-725362b67639}\Default') 2>$null
    if ($R) {
        $O.tags['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
        $O.tags['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
    }
    $Evt = @($Obj).foreach{
        $Att = @{}
        $_.PSObject.Properties | % { $Att[$_.Name]=$_.Value }
        ,@{ timestamp = Get-Date -Format o; attributes = $Att }
    }
    if (($Evt | measure).Count -eq 1) {
        $O['events'] = @($Evt)
        $O | ConvertTo-Json -Depth 8 -Compress >> $Json
    } elseif (($Evt | measure).Count -gt 1) {
        for ($i = 0; $i -lt ($Evt | measure).Count; $i += 200) {
            $C = $O.Clone()
            $C['events'] = $Evt[$i..($i + 199)]
            $C | ConvertTo-Json -Depth 8 -Compress >> $Json
        }
    }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { ni $Rtr -ItemType Directory }
if ($Param.Username) {
    $UserDir = (gwmi win32_userprofile | ? {
        $_.LocalPath -match "$([regex]::Escape($Param.Username))$" }).LocalPath
    if (-not $UserDir) {
        throw "No username found matching '$($Param.Username)'."
    }
}
$Json = Join-Path $Rtr "get_temp_file_$((Get-Date).ToFileTimeUtc()).json"
$Start = @{
    FilePath               = 'powershell.exe'
    ArgumentList           = "-Command &{$Script} '$Json'"
    PassThru               = $true
}
if ($UserDir) { $Start.ArgumentList += " '$UserDir'" }
start @Start | select Id, ProcessName | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Json',$Json)))
    $_ | ConvertTo-Json -Compress
}