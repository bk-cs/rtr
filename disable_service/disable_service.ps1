$Humio = @{ Cloud = ''; Token = '' }
switch ($Humio) {
    { $_.Cloud -and $_.Cloud -notmatch '/$' } { $_.Cloud += '/' }
    { ($_.Cloud -and !$_.Token) -or ($_.Token -and !$_.Cloud) } {
        throw "Both 'Cloud' and 'Token' are required when sending results to Humio."
    }
    { $_.Cloud -and $_.Cloud -notmatch '^https://cloud(.(community|us))Where-Object.humio.com/$' } {
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
function sendobj ([object]$Obj,[object]$Humio,[string]$Script) {
    if ($Obj -and $Humio.Cloud -and $Humio.Token) {
        $Iwr = @{ Uri = @($Humio.Cloud,'api/v1/ingest/humio-structured/') -join $null; Method = 'post';
            Headers = @{ Authorization = @('Bearer',$Humio.Token) -join ' '; ContentType = 'application/json' }}
        $A = @{ script = $Script; host = [System.Net.Dns]::GetHostName() }
        $R = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
        if ($R) {
            $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        $E = @($Obj).foreach{
            $C = $A.Clone()
            @($_.PSObject.Properties).foreach{ $C[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $C }
        }
        $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($E) }
        $Req = try {
            Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($B) -Compress) -UseBasicParsing
        } catch {}
        if ($Req.StatusCode -ne 200) {
            $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
            $Json = $Script -replace '\.ps1',"_$((Get-Date).ToFileTimeUtc()).json"
            if ((Test-Path $Rtr -PathType Container) -eq $false) { [void](New-Item $Rtr -ItemType Directory) }
            ConvertTo-Json @($B) -Compress >> (Join-Path $Rtr $Json)
        }
    }
}
function parse ([string]$Inputs) {
    $Param = if ($Inputs) { try { $Inputs | ConvertFrom-Json } catch { throw $_ }} else { [PSCustomObject]@{} }
    switch ($Param) {
        { !$_.Name } { throw "Missing required parameter 'Name'." }
    }
    $Param
}
$Param = parse $args[0]
$Service = Get-Service | Where-Object { $_.Name -eq $Param.Name }
if (!$Service) { throw "No results for service '$($Param.Name)'." }
if ($Service.StartType) { $Service | Set-Service -StartupType Disabled }
if ($Service.Status -ne 'Stopped') { $Service | Set-Service -Status Stopped }
$Out = Get-Service -Name $Param.Name | Select-Object Name,Status,StartType
sendobj $Out $Humio 'disable_service.ps1'
$Out | ConvertTo-Json -Compress