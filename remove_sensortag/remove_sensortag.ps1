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
function parse ([string]$Inputs) {
    $Param = if ($Inputs) { try { $Inputs | ConvertFrom-Json } catch { throw $_ }} else { [PSCustomObject]@{} }
    switch ($Param) {
        { !$_.SensorTag } { throw "Missing required parameter 'SensorTag'." }
    }
    $Param
}
function shumio ([string]$Script,[object[]]$Object,[string]$Cloud,[string]$Token) {
    if ($Object -and $Cloud -and $Token) {
        $Iwr = @{ Uri = $Cloud,'api/v1/ingest/humio-structured/' -join $null; Method = 'post';
            Headers = @{ Authorization = 'Bearer',$Token -join ' '; ContentType = 'application/json' }}
        $Att = @{ host = [System.Net.Dns]::GetHostName(); script = $Script }
        $Reg = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
        if ($Reg) {
            $Att['cid'] = (($Reg -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $Att['aid'] = (($Reg -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        [object[]]$Event = @($Object).foreach{
            $Clone = $Att.Clone()
            @($_.PSObject.Properties).foreach{ $Clone[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $Clone }
        }
        $Req = if ($Event) {
            $Body = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($Event) }
            try { Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($Body) -Depth 8) -UseBasicParsing } catch {}
        }
        if (!$Req -or $Req.StatusCode -ne 200) {
            $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
            $Json = $Script -replace '\.ps1',"_$((Get-Date).ToFileTimeUtc()).json"
            if ((Test-Path $Rtr -PathType Container) -eq $false) { [void](New-Item $Rtr -ItemType Directory) }
            ConvertTo-Json @($B) -Depth 8 >> (Join-Path $Rtr $Json)
        }
    }
}
$Param = parse $args[0]
$Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058-48c9-a204-72' +
    '5362b67639}\Default'
if ($Param.SensorTag) {
    $Del = @($Param.SensorTag)
    $Tag = (reg query $Key) -match "GroupingTags"
    $Val = ($Tag -split 'REG_SZ')[-1].Trim().Split(',').Where({ $Del -notcontains $_ }) -join ','
    if ($Val) {
        [void](reg add $Key /v GroupingTags /d $Val /f)
    } else {
        [void](reg delete $Key /v GroupingTags /f)
    }
}
$Out = [PSCustomObject]@{ SensorTag = "$((((reg query $Key 2>$null) -match 'GroupingTags') -split
    'REG_SZ')[-1].Trim())" }
shumio 'remove_sensortag.ps1' $Out $Humio.Cloud $Humio.Token
$Out | ConvertTo-Json -Compress