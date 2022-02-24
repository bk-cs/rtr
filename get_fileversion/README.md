## DESCRIPTION
List FileVersionInfo for Portable Executable (PE) file

## PARAMETER File
Path of the PE file (Required)

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

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
