## DESCRIPTION
List registered services

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

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
