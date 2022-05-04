## DESCRIPTION
Get FileVersionInfo for a Portable Executable (PE) file

## PARAMETER File
Path of the PE file (Required)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_fileversion" -CommandLine=```'{"File":"C:\\Windows\\system32\\notepad.exe"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ File = 'C:\Windows\system32\notepad.exe' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_fileversion' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY