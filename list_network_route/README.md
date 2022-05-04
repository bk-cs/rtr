## DESCRIPTION
List network routes

**NOTE:** The Json schema used in Workflows expects single object output. Because this script produces an array of
results, you may encounter the following error when using this script in a workflow:

```The script output does not validate against the output JSON schema```

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="list_network_route"
```
### PSFALCON
```powershell
PS>Invoke-FalconRtr runscript "-CloudFile='list_network_route'" -HostId <id>, <id>
```
### FALCONPY