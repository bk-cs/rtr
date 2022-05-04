## DESCRIPTION
Check if a specific service is present and output status

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_service" -CommandLine='{"Name":"WinRM"}'
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "$(@{ Name = 'WinRM' } | ConvertTo-Json -Compress)" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='list_service' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY