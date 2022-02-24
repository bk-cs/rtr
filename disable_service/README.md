## DESCRIPTION
Stop and disable a service

## PARAMETER Name
Service name (Required)

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

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
