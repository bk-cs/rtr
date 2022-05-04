## DESCRIPTION
List the most recent 1,000 events from the Windows Event Logs by LogName

## PARAMETER LogName
Windows Event Log Name (Required)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="list_eventlog" -CommandLine=```'{"LogName":"Application"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ LogName = 'Application' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='list_eventlog' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY