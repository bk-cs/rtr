$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
$Script = {
    param($Path, $Filter, $Include, $Exclude)
    try {
        $Param = @{ Path = $Path; Filter = $Filter; Recurse = $true; File = $true }
        $PSBoundParameters.GetEnumerator().Where({ $Param.Keys -notcontains $_.Key }).foreach{
            $Param[$_.Key] = $_.Value
        }
        Get-ChildItem @Param | Select-Object FullName, CreationTime, LastWriteTime, LastAccessTime |
        ForEach-Object {
            $_.PSObject.Properties | ForEach-Object {
                if ($_.Value -is [datetime]) {
                    $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }
                }
            }
            $_.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',
                (Get-FileHash $_.FullName).Hash.ToLower())))
            $_ | ConvertTo-Json -Compress
        }
    } catch {
        Write-Error "$(@{ message = $_ } | ConvertTo-Json -Compress)"
    }
}
$Inputs = @($Param.PSObject.Properties.foreach{ "-$($_.Name) '$($_.Value)'" }) -join ' '
$Start = @{
    FilePath               = 'powershell.exe'
    ArgumentList           = "-Command &{$Script} $Inputs"
    RedirectStandardError  = "$Rtr\find_file.log"
    RedirectStandardOutput = "$Rtr\find_file.json"
    PassThru               = $true
}
Start-Process @Start | Select-Object Id, ProcessName | ForEach-Object {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Log',$Rtr)))
    $_ | ConvertTo-Json -Compress
}