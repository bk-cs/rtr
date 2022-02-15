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
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$File = Confirm-FilePath $Param.File
if (!$File) {
    throw "Missing required parameter 'File'."
} elseif ((Test-Path $File) -eq $false) {
    throw "Cannot find path '$File' because it does not exist."
} elseif ((Test-Path $File -PathType Leaf) -eq $false) {
    throw "'File' must be a file."
}
$Json = "run_cli_tool_$((Get-Date).ToFileTimeUtc()).json"
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
$Start = @{
    FilePath               = $File
    RedirectStandardOutput = "$Rtr\$Json"
    PassThru               = $true
}
if ($Param.ArgumentList) {
    $Start['ArgumentList'] = $Param.ArgumentList
}
Start-Process @Start | ForEach-Object {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Output',($Start.RedirectStandardOutput))))
    if ($Param.Delete -eq $true) {
        $Wait = @{
            FilePath     = 'powershell.exe'
            ArgumentList = "-Command &{ Wait-Process $($_.Id); Start-Sleep 10; Remove-Item $File -Force }"
            PassThru     = $true
        }
        [void] (Start-Process @Wait)
    }
    $_ | Select-Object Id, ProcessName, Output | ConvertTo-Json -Compress
}