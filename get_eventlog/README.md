## DESCRIPTION
Retrieve the last 1,000 events from the Windows Event Logs by LogName

## PARAMETER LogName
Windows Event Log Name (Required)

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_eventlog" -CommandLine=```'{"LogName":"Application","Cloud":"https://cloud.community.humio.com","Token":"my_token"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ LogName = 'Application'; Cloud = 'https://cloud.community.humio.com'; Token = 'my_token' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_eventlog' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
