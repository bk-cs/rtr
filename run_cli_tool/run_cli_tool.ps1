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
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$File = validate $Param.File
if (!$File) {
    throw "Missing required parameter 'File'."
} elseif ((Test-Path $File) -eq $false) {
    throw "Cannot find path '$File' because it does not exist."
} elseif ((Test-Path $File -PathType Leaf) -eq $false) {
    throw "'File' must be a file."
}
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { ni $Rtr -ItemType Directory }
$Json = "run_cli_tool_$((Get-Date).ToFileTimeUtc()).json"
$Start = @{
    FilePath               = $File
    RedirectStandardOutput = (Join-Path $Rtr $Json)
    PassThru               = $true
}
if ($Param.ArgumentList) {
    $Start['ArgumentList'] = $Param.ArgumentList
}
start @Start | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Json',$Start.RedirectStandardOutput)))
    if ($Param.Delete -eq $true) {
        $Wait = @{
            FilePath     = 'powershell.exe'
            ArgumentList = "-Command &{ Wait-Process $($_.Id); Start-Sleep 10; Remove-Item $File -Force }"
            PassThru     = $true
        }
        [void] (start @Wait)
    }
    $_ | select Id, ProcessName, Json | ConvertTo-Json -Compress
}