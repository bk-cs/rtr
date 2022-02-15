function Confirm-FilePath ([string] $String) {
    if (![string]::IsNullOrEmpty($String)) {
        if ($String -match 'HarddiskVolume\d+\\') {
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
                $String | Where-Object { $_ -match $Ntp } | ForEach-Object {
                    $_ -replace $Ntp, $Vol.DriveLetter
                }
            }
        } else {
            $String
        }
    }
}
function Send-ToHumio ([string] $Cloud, [string] $Token, [array] $Array) {
    $Invoke = @{
        Uri     = "$($Cloud)api/v1/ingest/humio-structured/"
        Method  = 'post'
        Headers = @{ Authorization = "Bearer $($Token)"; ContentType = 'application/json' }
    }
    $Body = @{ tags = @{ script = 'send_log.ps1' }}
    $Reg = reg query ("HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-70" +
        "58-48c9-a204-725362b67639}\Default") 2>$null
    if ($Reg) {
        $Body.tags['cid'] = (($Reg -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
        $Body.tags['aid'] = (($Reg -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
    } else {
        $Body.tags['host'] = [System.Net.Dns]::GetHostName()
    }
    [array] $Locked = @()
    foreach ($Path in $Array) {
        try {
            $Stream = [System.IO.File]::Open($Path,'Open','Write')
            $Stream.Close()
            $Stream.Dispose()
        } catch {
            $Locked += $Path
        }
    }
    $Array | Where-Object { $Locked -notcontains $_ } | ForEach-Object {
        try {
            $Json = Get-Content $_ | ConvertFrom-Json
            $Clone = $Body.Clone()
            $Clone.tags['json'] = $_
            $Events = $Json | ForEach-Object {
                $Item = @{}
                $_.PSObject.Properties | ForEach-Object { $Item[$_.Name]=$_.Value }
                ,@{ timestamp  = Get-Date -Format o; attributes = $Item }
            }
            $Clone['events'] = @($Events)
            $Clone = ConvertTo-Json @($Clone) -Depth 8 -Compress
            $Output = try {
                $Request = Invoke-WebRequest @Invoke -Body $Clone -UseBasicParsing
                if ($Request.StatusCode -eq 200) {
                    Remove-Item $_
                    [PSCustomObject] @{ Json = $_; Sent = 'true'; Deleted = 'true' }
                } else {
                    [PSCustomObject] @{ Json = $_; Sent = 'false'; Deleted = 'false' }
                }
            } catch {
                [PSCustomObject] @{ Json = $_; Sent = 'false'; Deleted = 'false' }
            }
            $Output | ConvertTo-Json -Compress
        } catch {
            Write-Error "Unable to parse '$_'."
        }
    }
    if ($Locked) {
        [scriptblock] $Script = {
            param([string] $Cloud, [string] $Token, [array] $Locked)
            $Invoke = @{
                Uri     = ($Cloud + 'api/v1/ingest/humio-structured/')
                Method  = 'post'
                Headers = @{ Authorization = ('Bearer' + $Token); ContentType = 'application/json' }
            }
            $Body = @{ tags = @{ script = 'send_log.ps1' }}
            $Reg = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e' +
                '0423f-7058-48c9-a204-725362b67639}\Default') 2>$null
            if ($Reg) {
                $Body.tags['cid'] = (($Reg -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                $Body.tags['aid'] = (($Reg -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
            } else {
                $Body.tags['host'] = [System.Net.Dns]::GetHostName()
            }
            $Locked | ForEach-Object {
                do {
                    $Unlocked = try {
                        Start-Sleep -Seconds 30
                        $Stream = [System.IO.File]::Open($_,'Open','Write')
                        $Stream.Close()
                        $Stream.Dispose()
                        $true
                    } catch {
                        $false
                    }
                } until ( $Unlocked -eq $true )
                $Json = Get-Content $_ | ConvertFrom-Json
                $Clone = $Body.Clone()
                $Events = $Json | ForEach-Object {
                    $Item = @{}
                    $_.PSObject.Properties | ForEach-Object { $Item[$_.Name]=$_.Value }
                    ,@{ timestamp  = Get-Date -Format o; attributes = $Item }
                }
                $Clone['events'] = @($Events)
                $Clone = ConvertTo-Json @($Clone) -Depth 8 -Compress
                try {
                    $Request = Invoke-WebRequest @Invoke -Body $Clone -UseBasicParsing
                    if ($Request.StatusCode -eq 200) { Remove-Item $_ }
                } catch {}
            }
        }
        $Start = @{
            FilePath     = 'powershell.exe'
            ArgumentList = "-Command &{$Script} $Cloud $Token $($Locked -join ', ')"
            PassThru     = $true
        }
        Start-Process @Start | ForEach-Object {
            $Locked | ForEach-Object {
                [PSCustomObject] @{ Json = $_; Send = 'pending'; Deleted = 'pending' } | ConvertTo-Json -Compress
            }
        }
    }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
@('Cloud','Token').foreach{
    if (!$Param.$_) {
        throw "Missing required parameter '$_'."
    } elseif ($_ -eq 'Cloud') {
        if ($Param.$_ -notmatch 'https://cloud(.(community|us))?.humio.com') {
            throw "'$($Param.$_)' is not a valid Humio cloud value."
        } elseif ($Param.$_ -notmatch '/$') {
            $Param.$_ += '/'
        }
    } elseif ($_ -eq 'Token' -and $Param.$_ -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') {
        throw "'$($Param.$_)' is not a valid ingest token."
    }
}
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
[array] $Array = if ($Param.File) {
    $Param.File | ForEach-Object { Confirm-FilePath $_ }
} else {
    $Rtr = Join-Path $env:SystemRoot '\system32\drivers\CrowdStrike\Rtr'
    (Get-ChildItem $Rtr -Filter *.json -File -EA 0).FullName
}
if (-not $Array) {
    throw 'No Json files found for ingestion.'
}
$Array | Where-Object { -not [string]::IsNullOrEmpty($_) } | ForEach-Object {
    if ((Test-Path $_) -eq $false) {
        throw "Cannot find path '$_' because it does not exist."
    } elseif ((Test-Path $_ -PathType Leaf) -eq $false -or ($_ -notmatch '\.json$')) {
        throw "'$_' is not a Json file."
    }
}
Send-ToHumio $Param.Cloud $Param.Token $Array