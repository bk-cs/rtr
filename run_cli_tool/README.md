## DESCRIPTION
Run a CLI-based tool and save the output in a text file in the temporary RTR directory

## PARAMETER File
Path to the file

## PARAMETER ArgumentList
Arguments to supply during execution

## PARAMETER Delete
Delete the tool when complete

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="run_cli_tool" -CommandLine=```'{"File":"C:\\cast.exe","ArgumentList":"scan C:\\","Cloud":"https://cloud.community.humio.com","Token":"my_token"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ File = 'C:\cast.exe'; ArgumentList = 'scan C:\'; Cloud = 'https://cloud.community.humio.com'; Token = 'my_token' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='run_cli_tool' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
