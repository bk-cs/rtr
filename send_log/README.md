## DESCRIPTION
Send .txt, .csv, .json, and .log files to Humio and delete them upon successful transmission. Defaults to
supported files located in the temporary Real-time Response directory if 'File' is not specified.

## PARAMETER Cloud
Base Humio cloud URL (Required)

## PARAMETER Token
Humio ingestion token (Required)

## PARAMETER File
Path to a supported text file

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="send_log" -CommandLine=```'{"Cloud":"https://cloud.community.humio.com","Token":"my_token"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Cloud = 'https://cloud.community.humio.com'; Token = 'my_token' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='send_log' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY