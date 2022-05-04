## DESCRIPTION
List the most recent 1,000 events from the Windows Event Logs by LogName

## PARAMETER LogName
Windows Event Log Name (Required)

**NOTE:** The Json schema used in Workflows expects single object output. Because this script produces an array of
results, you may encounter the following error when using this script in a workflow:

```The script output does not validate against the output JSON schema```

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