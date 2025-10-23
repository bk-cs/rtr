function Convert-Hashtable([Parameter(Mandatory=$true)][psobject]$Object){
  [hashtable]$i=@{}
  $Object.PSObject.Properties|?{$null -ne $_.Value -and $_.Value -ne ''}|%{
    $i[($_.Name -replace '\s','_' -replace '\W',$null)]=$_.Value
  }
  $i
}
function Convert-Json([Parameter(Mandatory=$true)][string]$String){
  if($PSVersionTable.PSVersion.ToString() -lt 3.0){
    $Serializer.DeserializeObject($String)
  }else{
    $Object=$String|ConvertFrom-Json
    if($Object){Convert-Hashtable $Object}
  }
}
function Format-Result([Parameter(Mandatory=$true)][hashtable[]]$Hashtable,[string]$String){
  [void]([Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:ComputerName)|%{
    try{
      $_.OpenSubKey('SYSTEM\\CurrentControlSet\\Services\\CSAgent\\Sim')|%{
        foreach($i in @('AG','CU')){
          nv -Name $i -Value ([System.BitConverter]::ToString($_.GetValue($i))).Replace('-',$null).ToLower()
        }
      }
    }catch{}
  })
  [hashtable]@{script=$String;cid=$CU;aid=$AG;result=$Hashtable}
}
function Write-Json([Parameter(Mandatory=$true)][hashtable]$Hashtable){
  if($PSVersionTable.PSVersion.ToString() -lt 3.0){
    $Serializer.Serialize($Hashtable)
  }else{
    ConvertTo-Json $Hashtable -Depth 8 -Compress
  }
}
function Uninstall-App{
  param(
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$Key,
    [Parameter(Mandatory)][string]$Application,
    [string]$Version,
    [string]$Vendor
  )
  $Guid='\{[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\}'
  foreach($Name in $Key.GetSubKeyNames()){
    $SubKey=$Key.OpenSubKey($Name)
    [string[]]$GetValue=$SubKey.GetValueNames()|?{$_ -match
      '^(Display(Name|Version)|Publisher|(Quiet)?UninstallString)$'}
    if($GetValue -contains 'DisplayName' -and $SubKey.GetValue('DisplayName') -eq $Application){
      if($GetValue -contains 'DisplayVersion' -and $Version){
        $DisplayVersion=$SubKey.GetValue('DisplayVersion')
        if($DisplayVersion -ne $Version){
          throw('Registry version "{0}" does not match input version "{1}".' -f $DisplayVersion,$Version)
        }
      }
      if($GetValue -contains 'Publisher' -and $Vendor){
        $Publisher=$SubKey.GetValue('Publisher')
        if($Publisher -ne $Vendor){
          throw('Registry vendor "{0}" does not match input vendor "{1}".' -f $Publisher,$Vendor)
        }
      }
      if($GetValue -match 'UninstallString') {
        $Timestamp=Get-Date -Format o
        @('stdout','stderr')|%{nv -Name $_ -Value "$('UninstallApp',$Timestamp,$_ -join '_').log"}
        [hashtable]$Match=@{
          RedirectStandardOutput=(Join-Path $env:SystemDrive $StdOut)
          RedirectStandardError=(Join-Path $env:SystemDrive $StdErr)
          PassThru=$true
        }
        $Match['FilePath']=if($GetValue -contains 'QuietUninstallString'){
          $GetValue=$SubKey.GetValue('QuietUninstallString')
          if($GetValue -match '^".+"\s'){
            [regex]::Match($GetValue,'^".+"').Value
            $Match['ArgumentList']='"{0}"' -f [regex]::Match($GetValue,'(?<="\s).+$').Value
          }else{
            $GetValue
          }
        }elseif($GetValue -contains 'UninstallString'){
          $GetValue=$SubKey.GetValue('UninstallString')
          $GuidValue=[regex]::Match($GetValue,$Guid).Value
          if($GuidValue){
            'msiexec.exe'
            $Match['ArgumentList']="/x $GuidValue /q"
          }elseif($GetValue -match '^".+"\s'){
            [regex]::Match($GetValue,'^".+"').Value
            $Match['ArgumentList']='"{0}"' -f [regex]::Match($GetValue,'(?<="\s).+$').Value
          }else{
            $GetValue
          }
        }
        if($Match.FilePath){
          $Message='Attempting removal of "{0}". Check "{1}" for logs.' -f $Application,$env:SystemDrive
          start @Match|%{[hashtable]@{pid=$_.Id;name=$_.ProcessName;message=$Message}}
        }
      }
    }
  }
}
try{
  if($PSVersionTable.PSVersion.ToString() -lt 3.0){
    Add-Type -AssemblyName System.Web.Extensions
    $Serializer=New-Object System.Web.Script.Serialization.JavascriptSerializer
  }
  if($args[0]){$Param=Convert-Json $args[0]}
  [hashtable[]]$Output=@('Users','LocalMachine')|%{
    if($_ -eq 'Users'){
      $HKU=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($_,$env:ComputerName)
      if($HKU){
        $HKU.GetSubKeyNames()|?{(gwmi -Query "Select * FROM Win32_Account WHERE sid LIKE 'S-1-5-21%'"|
        select -ExpandProperty Sid) -contains $_}|%{
          @("$_\\Software","$_\\Software\\Wow6432Node")|%{
            $Key=try{$HKU.OpenSubKey("$_\\Microsoft\\Windows\\CurrentVersion\\Uninstall")}catch{}
            if($Key){Uninstall-App $Key @Param}
          }
        }
      }
    }else{
      $HKLM=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($_,$env:ComputerName)
      if($HKLM){
        @('Software\\','Software\\Wow6432Node')|%{
          $Key=try{$HKLM.OpenSubKey("$_\\Microsoft\\Windows\\CurrentVersion\\Uninstall")}catch{}
          if($Key){Uninstall-App $Key @Param}
        }
      }
    }
  }
  if($Output){
    Write-Json (Format-Result $Output UninstallApp)
  }else{
    throw ('No applications found named "{0}".' -f $Param.Application)
  }
}catch{
  throw $_
}