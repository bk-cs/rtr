## SYNOPSIS
List prefetch files

**NOTE:** The Json schema used in Workflows expects single object output. Because this script produces an array of
results, you may encounter the following error when using this script in a workflow:

```The script output does not validate against the output JSON schema```

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="list_prefetch"
```
### PSFALCON
```powershell
PS>Invoke-FalconRtr runscript "-CloudFile='list_prefetch'" -HostId <id>, <id>
```
### FALCONPY