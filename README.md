# bk-cs/rtr
Scripts and schema for use with CrowdStrike Falcon Real-time Response and Falcon Fusion Workflows.

**NOTE:** If you enter your Humio `Cloud` and `Token` values inside of the `$Humio` value at the beginning of each
script, the results from the script will be output to Real-time Response and also sent to your Humio repository.

```powershell
$Humio = @{ Cloud = 'https://cloud.community.humio.com'; Token = '<my_ingest_token_guid>' }
```