## DESCRIPTION
List local disk volume(s)

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_volume" -CommandLine=```'{"Cloud":"https://cloud.community.humio.com","Token":"my_token"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Cloud = 'https://cloud.community.humio.com'; Token = 'my_token' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_volume' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
