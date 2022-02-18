$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
if ((Test-Path $Param.Path -PathType Container) -eq $false) {
    throw "Cannot find path '$($Param.Path)' because it does not exist or is not a directory."
}
$Script = {
    param($Json, $Path, $Filter, $Include, $Exclude)
    function hash ([object] $Obj, [string] $Str) {
        foreach ($I in $Obj) {
            $E = ($Obj | ? { $_.$Str -eq $I.$Str } | select -Unique).Sha256
            $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
            $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
        }
        $Obj
    }
    $Param = @{ Path = $Path; Filter = $Filter; Recurse = $true; File = $true }
    $PSBoundParameters.GetEnumerator().Where({ $Param.Keys -notcontains $_.Key }).foreach{
        $Param[$_.Key] = $_.Value
    }
    $Obj = gci @Param -EA 0 | select FullName, CreationTime, LastWriteTime, LastAccessTime | % {
        $_.PSObject.Properties | % {
            if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value } }
        }
        $_
    }
    $Obj = hash $Obj FullName
    $O = @{ tags = @{ json = $Json; script = $Json -replace '_\d+\.json$','.ps1';
        host = [System.Net.Dns]::GetHostName() }}
    $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-' +
        '7058-48c9-a204-725362b67639}\Default') 2>$null
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
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { ni $Rtr -ItemType Directory }
$Json = Join-Path $Rtr "find_file_$((Get-Date).ToFileTimeUtc()).json"
$Inputs = @($Param.PSObject.Properties.foreach{ "-$($_.Name) '$($_.Value)'" }) -join ' '
$Start = @{
    FilePath               = 'powershell.exe'
    ArgumentList           = "-Command &{$Script} '$Json' $Inputs"
    PassThru               = $true
}
start @Start | select Id, ProcessName | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Json',$Json)))
    $_ | ConvertTo-Json -Compress
}