## DESCRIPTION
Change the password for a local user

## PARAMETER Username
Local username (Required)

## PARAMETER Password
Password (Required)

## PARAMETER ForceLogoff
Force logoff if the user has an active session

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="set_local_password" -CommandLine=```'{"Username":"IEUser","Password":"hunter2","ForceLogOff":true}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ Username = 'IEUser'; Password = 'hunter2'; ForceLogoff = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='set_local_password' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY