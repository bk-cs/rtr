$Humio = @{ Cloud = ''; Token = '' }
switch ($Humio) {
    { $_.Cloud -and $_.Cloud -notmatch '/$' } { $_.Cloud += '/' }
    { ($_.Cloud -and !$_.Token) -or ($_.Token -and !$_.Cloud) } {
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
[scriptblock]$Script = {
    param([int]$Id,[boolean]$Delete,[string]$OutLog,[string]$ErrLog,[string]$Cloud,[string]$Token)
    $Run = (Get-Process -Id $Id).Path; Wait-Process $Id
    if ($Delete -eq $true -and (Test-Path $Run -PathType Leaf) -eq $true) {
        Start-Sleep 5
        Remove-Item $Run
    }
    [string[]]$Logs = @($OutLog,$ErrLog).foreach{ if ((Test-Path $_ -PathType Leaf) -eq $true) { $_ }}
    if ($Cloud -and $Token) {
        $Iwr = @{ Uri = $Cloud,'api/v1/ingest/humio-structured/' -join $null; Method = 'post';
            Headers = @{ Authorization = 'Bearer',$Token -join ' '; ContentType = 'application/json' }}
        foreach ($File in $Logs) {
            [string[]]$Text = try { (Get-Content $File).Normalize() } catch {}
            if ($Text) {
                $A = @{ host = [System.Net.Dns]::GetHostName(); script = 'run_cli_tool.ps1'; file = $File }
                $R = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
                if ($R) {
                    $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                    $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
                }
                [object[]]$Json = try { $Text | ConvertFrom-Json } catch {}
                [object[]]$E = if ($Json) {
                    @($Json).foreach{
                        $C = $A.Clone()
                        @($_.PSObject.Properties).foreach{ $C[$_.Name] = $_.Value }
                        ,@{ timestamp = Get-Date -Format o; attributes = $C }
                    }
                } else {
                    @($Text | Where-Object { ![string]::IsNullOrEmpty($_) }).foreach{
                        ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $_ }
                    }
                }
                $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @(@($E)[$i..($i + 199)]) }
                $Req = Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($B) -Depth 8) -UseBasicParsing
                if (!$Req -or $Req.StatusCode -ne 200) {
                    ConvertTo-Json @($B) -Depth 8 >> ($File -replace '\.log$','.json')
                }
                if ($Req -and (($Req.StatusCode | Sort-Object -Unique) -join ', ') -eq 200) { Remove-Item $File }
            } elseif ((Test-Path $File -PathType Leaf) -eq $true -and !(Get-Content $File)) {
                Remove-Item $File
            }
        }
    }
}
function parse ([string]$Inputs) {
    $Param = if ($Inputs) { try { $Inputs | ConvertFrom-Json } catch { throw $_ }} else { [PSCustomObject]@{} }
    switch ($Param) {
        { !$_.File } { throw "Missing required parameter 'File'." }
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
            }
        }
    }
    $Param
}
function validate ([string]$Str) {
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
            foreach ($Vol in (Get-CimInstance Win32_Volume | Where-Object { $_.DriveLetter })) {
                [void]$K32::QueryDosDevice($Vol.DriveLetter,$StrBld,65536)
                $Ntp = [regex]::Escape($StrBld.ToString())
                $Str | Where-Object { $_ -match $Ntp } | ForEach-Object { $_ -replace $Ntp, $Vol.DriveLetter }
            }
        }
        else { $Str }
    }
}
$Param = parse $args[0]
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { [void](New-Item $Rtr -ItemType Directory) }
$Date = (Get-Date).ToFileTimeUtc()
$OutLog = Join-Path $Rtr "run_cli_tool_$Date.stdout.log"
$ErrLog = Join-Path $Rtr "run_cli_tool_$Date.stderr.log"
$Start = @{ FilePath = $Param.File; RedirectStandardOutput = $OutLog; RedirectStandardError = $ErrLog }
if ($Param.ArgumentList) { $Start['ArgumentList'] = $Param.ArgumentList }
@(Start-Process @Start -PassThru).foreach{
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Output',$Rtr)))
    $Delete = if ($Param.Delete -eq $true) { '$true' } else { '$false' }
    $ArgList = @('-Command &{',$Script,'}',$_.Id,$Delete) -join ' '
    if ($Humio.Cloud -and $Humio.Token) {
        $ArgList = @($ArgList,$OutLog,$ErrLog,$Humio.Cloud,$Humio.Token) -join ' '
        Write-Host $ArgList
        [void](Start-Process powershell.exe $ArgList -PassThru)
    }
    $_ | Select-Object Id,ProcessName,Output | ConvertTo-Json -Compress
}