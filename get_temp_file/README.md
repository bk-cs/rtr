## SYNOPSIS
List temporary files. Because of the potential for the script to time out when run using
Real-time Response, results will be sent to your Humio instance (if 'Cloud' and 'Token' are provided) or
written to a Json file in the temporary Rtr directory.

## PARAMETER Username
Filter to temporary files for a specific user. If left unspecified, temporary files from the system and all
user directories will be listed.

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_temp_file" -CommandLine=```'{"Username":"IEUser","Cloud":"https://cloud.community.humio.com","Token":"my_token"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Username = 'IEUser'; Cloud = 'https://cloud.community.humio.com'; Token = 'my_token' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_temp_file' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
