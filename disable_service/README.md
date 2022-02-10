## DESCRIPTION
Stop and disable a service

## PARAMETER Name
Service name (Required)

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="disable_service" -CommandLine=```'{"Name":"WinRM"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Name = 'WinRM' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='disable_service' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
