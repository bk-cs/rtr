$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
if ($Param.Path) {
    $Param.Path = $Param.Path -replace '\\\\','\'
}
if ($Param.Path -match '^\\Device') {
$Definition = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
    $StringBuilder = New-Object System.Text.StringBuilder(65536)
    $Kernel32 = Add-Type -MemberDefinition $Definition -Name Kernel32 -Namespace Win32 -PassThru
    foreach ($Volume in (Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter })) {
        $Value = $Kernel32::QueryDosDevice($Volume.DriveLetter,$StringBuilder,65536)
        $NtPath = [regex]::Escape($StringBuilder.ToString())
        $Param.Path | Where-Object { $_ -match $NtPath } | ForEach-Object {
            $Param.Path = $Param.Path -replace $NtPath, $Volume.DriveLetter
        }
    }
}
if ((Test-Path $Param.Path) -eq $false) {
    throw "Cannot find path '$($Param.Path)' because it does not exist."
} elseif ((Test-Path $Param.Path -PathType Leaf) -eq $false) {
    throw "'Path' must be a file."
}
$Output = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Param.Path) | Select-Object OriginalFilename,
    FileDescription, ProductName, CompanyName, FileName, FileVersion | ForEach-Object {
        $_.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',
            (Get-FileHash $_.FileName).Hash.ToLower())))
        $_
    } | ConvertTo-Json -Compress
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\get_fileversion.json"
}
$Output