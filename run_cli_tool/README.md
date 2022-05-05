## DESCRIPTION
Run a CLI-based tool and capture the output. Because of the potential for the script to time out when run using
Real-time Response, results will be written to log files in the temporary Rtr directory.

## PARAMETER File
Path of the file to execute

## PARAMETER ArgumentList
Arguments to supply during execution

## PARAMETER Delete
Delete 'File' when complete

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="run_cli_tool" -CommandLine=```'{"File":"C:\\cast.exe","ArgumentList":"scan C:\\"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ File = 'C:\cast.exe'; ArgumentList = 'scan C:\'} | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='run_cli_tool' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY