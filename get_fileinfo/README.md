## DESCRIPTION
Check for a file and return information about it

## PARAMETER File
Path of the file (Required)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_fileinfo" -CommandLine=```'{"File":"C:\\Windows\\system32\\notepad.exe"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ File = 'C:\Windows\system32\notepad.exe' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_fileinfo' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY