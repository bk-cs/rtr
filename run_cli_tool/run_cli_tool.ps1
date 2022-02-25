[scriptblock] $Shumio = {
    param([int] $Id, [string] $Delete, [string] $OutLog, [string] $ErrLog, [string] $Cloud, [string] $Token)
    $Run = (ps -Id $Id).Path; Wait-Process $Id
    if ($Delete -eq $true -and (Test-Path $Run -PathType Leaf) -eq $true) { sleep 5; rm $Run -Force }
    [array] $Arr = @($OutLog,$ErrLog).foreach{ if ((Test-Path $_ -PathType Leaf) -eq $true) { ,$_ }}
    if ($Cloud -and $Token) {
        $Iwr = @{ Uri = @($Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post';
            Headers = @{ Authorization = @('Bearer', $Token) -join ' '; ContentType = 'application/json' }}
        foreach ($File in $Arr) {
            $Obj = if ($File -match '\.csv$') {
                try { ipcsv $File } catch {}
            } elseif ($File -match '\.json$') {
                try { gc $File | ConvertFrom-Json } catch {}
            } elseif ($File -match '\.(log|txt)$') {
                try { (gc $File).Normalize() } catch {}
            }
            $Req = if ($Obj -is [PSCustomObject] -and $Obj.tags -and $Obj.events) {
                iwr @Iwr -Body (ConvertTo-Json @($Obj) -Depth 8 -Compress) -UseBasicParsing
            } elseif ($Obj) {
                $A = @{ script = 'run_cli_tool.ps1'; file = $File }
                $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{1' +
                    '6e0423f-7058-48c9-a204-725362b67639}\Default') 2>$null
                if ($R) {
                    $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                    $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
                }
                $E = if ($Obj -is [PSCustomObject]) {
                    $Obj | % {
                        $C = $A.Clone()
                        $_.PSObject.Properties | % { $C[$_.Name]=$_.Value }
                        ,@{ timestamp = Get-Date -Format o; attributes = $C }
                    }
                } else {
                    if (($Obj | measure).Count -eq 1) {
                        ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $Obj }
                    } elseif (($Obj | measure).Count -gt 1) {
                        $Obj | ? { -not [string]::IsNullOrEmpty($_) } | % {
                            ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $_ }
                        }
                    }
                }
                for ($i = 0; $i -lt ($E | measure).Count; $i += 200) {
                    $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @(@($E)[$i..($i + 199)]) }
                    iwr @Iwr -Body (ConvertTo-Json @($B) -Depth 8 -Compress) -UseBasicParsing
                }
            } else {
                if ((Test-Path $File -PathType Leaf) -eq $true -and -not (Get-Content $File)) { rm $File }
            }
            if ($Req -and (($Req.StatusCode | sort -Unique) -join ', ') -eq 200) { rm $File }
        }
    }
}
function parse ([string] $String) {
    $Param = try { $String | ConvertFrom-Json } catch { throw $_ }
    switch ($Param) {
        { -not $_.File } {
            throw "Missing required parameter 'File'."
        }
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
            }
        }
        { $_.Cloud -and $_.Cloud -notmatch '/$' } {
            $_.Cloud += '/'
        }
        { ($_.Cloud -and -not $_.Token) -or ($_.Token -and -not $_.Cloud) } {
            throw "Both 'Cloud' and 'Token' are required when sending results to Humio."
        }
        { $_.Cloud -and $_.Cloud -notmatch '^https://cloud(.(community|us))?.humio.com/$' } {
            throw "'$($_.Cloud)' is not a valid Humio cloud value."
        }
        { $_.Token -and $_.Token -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$' } {
            throw "'$($_.Token)' is not a valid Humio ingest token."
        }
        { $_.Cloud -and $_.Token -and [Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12' } {
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            } catch {
                throw $_
            }
        }
    }
    $Param
}
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
$Param = if ($args[0]) { parse $args[0] }
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { ni $Rtr -ItemType Directory }
$OutLog = Join-Path $Rtr "run_cli_tool_$((Get-Date).ToFileTimeUtc()).stdout.log"
$ErrLog = Join-Path $Rtr "run_cli_tool_$((Get-Date).ToFileTimeUtc()).stderr.log"
$Start = @{ FilePath = $Param.File; RedirectStandardOutput = $OutLog; RedirectStandardError = $ErrLog }
if ($Param.ArgumentList) { $Start['ArgumentList'] = $Param.ArgumentList }
start @Start -PassThru | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Output',$Rtr)))
    if ($Param.Delete -eq $true -or ($Param.Cloud -and $Param.Token)) {
        $ArgList = @('-Command &{', $Shumio, '}', $_.Id, $Param.Delete) -join ' '
        if ($Param.Cloud -and $Param.Token) {
            $ArgList = @($ArgList, $OutLog, $ErrLog, $Param.Cloud, $Param.Token) -join ' '
        }
        [void] (start powershell.exe $ArgList -PassThru)
    }
    $_ | select Id, ProcessName, Output | ConvertTo-Json -Compress
}