## DESCRIPTION
Send plaintext files to Humio.

**The Humio `Cloud` and `Token` values must be set within the script, inside the `$Humio` variable**.

If the target file is currently locked, a secondary PowerShell process will be launched to wait for the file to be
available. An access check is performed every 30 seconds for a total of 5 minutes.

Defaults to supported files located in the temporary Real-time Response directory if 'File' is not specified.

**NOTE:** The Json schema used in Workflows expects single object output. Because this script produces an array of
results, you may encounter the following error when using this script in a workflow:

```The script output does not validate against the output JSON schema```

## PARAMETER File
Path to a plaintext file

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="send_log" -CommandLine=```'{"File":"C:\\Filename.csv"}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "$(@{ File = "C:\Filename.csv" } | ConvertTo-Json -Compress)" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='send_log' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY