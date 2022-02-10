## DESCRIPTION
List registered services

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_service" -CommandLine=```'{"Filter":"WinRM"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'WinRM' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_service' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
