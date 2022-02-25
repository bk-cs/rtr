## DESCRIPTION
Run a CLI-based tool and save the output in a text file in the temporary RTR directory

## PARAMETER File
Path to the file

## PARAMETER ArgumentList
Arguments to supply during execution

## PARAMETER Delete
Delete the tool when complete

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="run_cli_tool" -CommandLine=```'{"File":"C:\\cast.exe","ArgumentList":"scan C:\\"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ File = 'C:\cast.exe'; ArgumentList = 'scan C:\' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='run_cli_tool' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
