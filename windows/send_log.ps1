function Confirm-FilePath ([string] $String) {
    $String = $String -replace '\\\\','\'
    if ($String -match '^\\Device') {
        $Def = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
        $StrBld = New-Object System.Text.StringBuilder(65536)
        $K32 = Add-Type -MemberDefinition $Def -Name Kernel32 -Namespace Win32 -PassThru
        foreach ($Vol in (Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter })) {
            [void] $K32::QueryDosDevice($Vol.DriveLetter,$StrBld,65536)
            $Ntp = [regex]::Escape($StrBld.ToString())
            $String -replace $Ntp, $Vol.DriveLetter
        }
    } else {
        $String
    }
}
function Send-ToHumio ([string] $Cloud, [string] $Token, [string] $String) {
    $Json = try { Get-Content $String | ConvertFrom-Json } catch {}
    if ($Json) {
        $Tags = @{
            script = 'send_log.ps1'
            json   = Split-Path $String -Leaf
        }
        $Reg = reg query ("HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423" +
            "f-7058-48c9-a204-725362b67639}\Default") 2>$null
        if ($Reg) {
            $Tags['cid'] = (($Reg -match "CU") -split "REG_BINARY")[-1].Trim().ToLower()
            $Tags['aid'] = (($Reg -match "AG") -split "REG_BINARY")[-1].Trim().ToLower()
        } else {
            $Tags['host'] = [System.Net.Dns]::GetHostName()
        }
        $Events = $Json | ForEach-Object {
            $Item = @{}
            $_.PSObject.Properties | ForEach-Object { $Item[$_.Name]=$_.Value }
            @{ timestamp  = Get-Date -Format o; attributes = $Item }
        }
        $Invoke = @{
            Uri     = "$($Cloud)api/v1/ingest/humio-structured/"
            Method  = 'post'
            Headers = @{ Authorization = "Bearer $($Token)"; ContentType = 'application/json' }
            Body    = ConvertTo-Json @(@{ tags = $Tags; events = @( $Events ) }) -Depth 8 -Compress
        }
        $Output = try {
            $Request = Invoke-WebRequest @Invoke -UseBasicParsing
            if ($Request.StatusCode -eq 200) {
                Remove-Item $String
            }
            [PSCustomObject] @{
                Json    = $String
                Sent    = $true
                Deleted = if (Test-Path $String) { $false } else { $true }
            }
        } catch {
            [PSCustomObject] @{
                Json    = $String
                Sent    = $false
                Deleted = $false
            }
        }
        $Output | ConvertTo-Json -Compress
    } else {
        throw "Failed to parse '$String'."
    }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
@('Cloud','Token').foreach{
    if (!$Param.$_) {
        throw "Missing required parameter '$_'."
    } elseif ($_ -eq 'Cloud' -and $Param.$_ -notmatch 'https://cloud(.(community|us))?.humio.com') {
        throw "'$($Param.$_)' is not a valid Humio cloud value."
    } elseif ($_ -eq 'Token' -and $Param.$_ -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') {
        throw "'$($Param.$_)' is not a valid ingest token."
    }
}
if ($Param.Cloud -notmatch '/$') {
    $Param.Cloud += '/'
}
if (-not $Param.Path) {
    $Rtr = Join-Path $env:SystemRoot '\system32\drivers\CrowdStrike\Rtr'
    $Param.PSObject.Properties.Add((New-Object PSNoteProperty('Path',
        (Get-ChildItem $Rtr -Filter *.json -File -EA 0).FullName))) 
}
$Param.Path | ForEach-Object {
    $Path = Confirm-FilePath $_
    if (-not(Test-Path $Path)) {
        throw "Cannot find path '$Path' because it does not exist."
    } elseif (-not(Test-Path $Path -PathType Leaf)) {
        throw "'Path' must be a file."
    } elseif ($Path -notmatch '\.json$') {
        throw "'$Path' has an invalid extension."
    }
    Send-ToHumio $Param.Cloud $Param.Token $Path
}