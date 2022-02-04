function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = if ($PSVersionTable.PSVersion.ToString() -gt 5) {
    try {
        Set-LocalUser -Name $Param.Username -Password ($Param.Password |
            ConvertTo-SecureString -AsPlainText -Force)
        [PSCustomObject] @{ Username = $Param.Username; PasswordSet = $true }
    } catch {
        throw $_
    }
} else {
    try {
        ([adsi]("WinNT://$($env:ComputerName)/$($Param.Username), user")).SetPassword($Param.Password)
        [PSCustomObject] @{ Username = $Param.Username; PasswordSet = $true }
    } catch {
        throw $_
    }
}
$Session = Get-Process -IncludeUserName -EA 0 | Where-Object { $_.SessionId -ne 0 -and $_.UserName -match
    $Param.Username } | Select-Object SessionId, UserName | Sort-Object -Unique
$Active = if ($Session.SessionId) {
    if ($Param.ForceLogoff -eq $true) {
        logoff $Session.SessionId
        $false
    } else {
        $true
    }
} else {
    $false
}
$Output.PSObject.Properties.Add((New-Object PSNoteProperty('ActiveSession',$Active)))
Write-Output $Output $Param "set_local_password_$((Get-Date).ToFileTimeUtc()).json"