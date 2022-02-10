## DESCRIPTION
Display a pop-up message for all active users

## PARAMETER Message
Message to display

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="send_message" -CommandLine=```'{"Message":"This is an example"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Message = 'This is an example' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='send_message' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
