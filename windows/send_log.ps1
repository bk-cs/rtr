$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
if ($Param.Path) {
    $Param.Path = $Param.Path -replace '\\\\','\'
}
@('Cloud','Token').foreach{
    if (!$Param.$_) {
        throw "Must provide '$_'."
    } elseif ($_ -eq 'Cloud' -and $Param.$_ -notmatch 'https://cloud(.(community|us))?.humio.com') {
        throw "'$($Param.$_)' is not a valid Humio cloud value."
    } elseif ($_ -eq 'Token' -and $Param.$_ -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') {
        throw "'$($Param.$_)' is not a valid ingest token."
    }
}
if ($Param.Cloud -notmatch '/$') {
    $Param.Cloud += '/'
}
if ($Param.Path -and $Param.Path -match '^\\Device') {
    $Def = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
    $StringBuilder = New-Object System.Text.StringBuilder(65536)
    $Kernel32 = Add-Type -MemberDefinition $Def -Name Kernel32 -Namespace Win32 -PassThru
    foreach ($Volume in (Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter })) {
        $Value = $Kernel32::QueryDosDevice($Volume.DriveLetter,$StringBuilder,65536)
        $NtPath = [regex]::Escape($StringBuilder.ToString())
        $Param.Path | Where-Object { $_ -match $NtPath } | ForEach-Object {
            $Param.Path = $Param.Path -replace $NtPath, $Volume.DriveLetter
        }
    }
}
if (-not $Param.Path) {
    $Rtr = Join-Path $env:SystemRoot '\system32\drivers\CrowdStrike\Rtr'
    $Param.PSObject.Properties.Add((New-Object PSNoteProperty('Path',
        (Get-ChildItem $Rtr -Filter *.json -File -EA 0).FullName))) 
}
$Param.Path | ForEach-Object {
    if (-not(Test-Path $_)) {
        throw "Cannot find path '$_' because it does not exist."
    } elseif (-not(Test-Path $_ -PathType Leaf)) {
        throw "'Path' must be a file."
    } elseif ($_ -notmatch '\.json$') {
        throw "'$_' has an invalid extension."
    }
    $Json = try { Get-Content $_ | ConvertFrom-Json } catch { throw "Unable to parse '$($_)'." }
    $Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058-48c9-a20' +
        '4-725362b67639}\Default'
    $Reg = reg query "$Key"
    $Tags = @{
        cid    = (($Reg -match "CU") -split "REG_BINARY")[-1].Trim().ToLower()
        aid    = (($Reg -match "AG") -split "REG_BINARY")[-1].Trim().ToLower()
        script = 'send_log.ps1'
        json   = Split-Path $_ -Leaf
    }
    $Events = $Json | ForEach-Object {
        $Item = @{}
        $_.PSObject.Properties | ForEach-Object { $Item[$_.Name]=$_.Value }
        @{ timestamp  = Get-Date -Format o; attributes = $Item }
    }
    $Invoke = @{
        Uri     = "$($Param.Cloud)api/v1/ingest/humio-structured/"
        Method  = 'post'
        Headers = @{ Authorization = "Bearer $($Param.Token)"; ContentType = 'application/json' }
        Body    = ConvertTo-Json @(@{ tags = $Tags; events = @( $Events ) }) -Depth 8 -Compress
    }
    try {
        $Request = Invoke-WebRequest @Invoke -UseBasicParsing
        if ($Request.StatusCode -eq 200) {
            Remove-Item $_
        }
    } catch {
        throw $_.Exception.Message
    }
    [PSCustomObject] @{ StatusCode = $Request.StatusCode; StatusDescription = $Request.StatusDescription;
        Json = $_; Deleted = if (Test-Path $_) { $false } else { $true } } | ConvertTo-Json -Compress
}
