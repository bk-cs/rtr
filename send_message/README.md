## DESCRIPTION
Display a pop-up message for all active users

## PARAMETER Message
Message to display

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

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
