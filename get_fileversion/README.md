## DESCRIPTION
List FileVersionInfo for Portable Executable (PE) file

## PARAMETER Path
Path of the PE file (Required)

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_fileversion" -CommandLine=```'{"File":"C:\\Windows\\system32\\notepad.exe"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ File = 'C:\Windows\system32\notepad.exe' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_fileversion' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
