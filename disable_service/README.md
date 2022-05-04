## DESCRIPTION
Stop and disable a service

## PARAMETER Name
Service name (Required)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="disable_service" -CommandLine=```'{"Name":"WinRM"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ Name = 'WinRM' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='disable_service' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY