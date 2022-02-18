function validate ([string] $Str) {
    if (![string]::IsNullOrEmpty($Str)) {
        if ($Str -match 'HarddiskVolume\d+\\') {
            $Def = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
            $StrBld = New-Object System.Text.StringBuilder(65536)
            $K32 = Add-Type -MemberDefinition $Def -Name Kernel32 -Namespace Win32 -PassThru
            foreach ($Vol in (gwmi Win32_Volume | ? { $_.DriveLetter })) {
                [void] $K32::QueryDosDevice($Vol.DriveLetter,$StrBld,65536)
                $Ntp = [regex]::Escape($StrBld.ToString())
                $Str | ? { $_ -match $Ntp } | % { $_ -replace $Ntp, $Vol.DriveLetter }
            }
        }
        else { $Str }
    }
}
function output ([object] $Obj, [object] $Param, [string] $Json) {
    if ($Obj -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr -PathType Container) -eq $false) { ni $Rtr -ItemType Directory }
        $O = @{ tags = @{ json = $Json; script = $Json -replace '_\d+\.json$','.ps1';
            host = [System.Net.Dns]::GetHostName() }}
        $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-' +
            '7058-48c9-a204-725362b67639}\Default') 2>$null
        if ($R) {
            $O.tags['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $O.tags['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        $Evt = $Obj | % {
            $Att = @{}
            $_.PSObject.Properties | % { $Att[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $Att }
        }
        if (($Evt | measure).Count -eq 1) {
            $O['events'] = @($Evt)
            $O | ConvertTo-Json -Depth 8 -Compress >> (Join-Path $Rtr $Json)
        } elseif (($Evt | measure).Count -gt 1) {
            for ($i = 0; $i -lt ($Evt | measure).Count; $i += 200) {
                $C = $O.Clone()
                $C['events'] = $Evt[$i..($i + 199)]
                $C | ConvertTo-Json -Depth 8 -Compress >> (Join-Path $Rtr $Json)
            }
        }
    }
    $Obj | ConvertTo-Json -Compress
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$File = validate $Param.File
if (!$File) {
    throw "Missing required parameter 'File'."
} elseif ((Test-Path $File) -eq $false) {
    throw "Cannot find path '$File' because it does not exist."
} elseif ((Test-Path $File -PathType Leaf) -eq $false) {
    throw "'File' must be a file."
}
$Out = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($File) | select OriginalFilename,
FileDescription, ProductName, CompanyName, FileName, FileVersion | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',(Get-FileHash $_.FileName).Hash.ToLower())))
    $_
}
output $Out $Param "get_fileversion_$((Get-Date).ToFileTimeUtc()).json"