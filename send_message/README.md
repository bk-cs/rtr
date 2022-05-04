## DESCRIPTION
Display a pop-up message for all active users

## PARAMETER Message
Message to display

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="send_message" -CommandLine=```'{"Message":"This is an example"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ Message = 'This is an example' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='send_message' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY