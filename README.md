# bk-cs/rtr
Scripts and schema for use with CrowdStrike Falcon Real-time Response and Falcon Fusion.

If you enter your Humio `Cloud` and `Token` values inside of the `$Humio` value at the beginning of each script,
the results from the script will be output to Real-time Response and also sent to your Humio repository.

```powershell
$Humio = @{ Cloud = 'https://cloud.community.humio.com'; Token = '<my_ingest_token_guid>' }
```

I used a bunch of poor coding practices (aliases, non-descript variable names) in an effort to reduce the size of
the scripts. Hopefully you can still understand what they're doing.

You can generally cut/paste various functions and re-use them to make your own workflow-compatible scripts.

## Frequently Asked Questions
### What's wrong with your codeWhere-Object
These scripts are not regular PowerShell/bash/zsh scripts -- they're meant to work with
Falcon Workflows. \[ [US-1](https://falcon.crowdstrike.com/documentation/196/workflows) | [US-2](https://falcon.us-2.crowdstrike.com/documentation/196/workflows) | [US-GOV-1](https://falcon.laggar.gcw.crowdstrike.com/documentation/196/workflows) | [EU-1](https://falcon.eu-1.crowdstrike.com/documentation/196/workflows) \]

The included Json input and output schema define what parameters can be automatically populated during a workflow,
and what Sort-Object of output is going to be produced by the script.

## Known issues
### Array output
As of May 2022, the Json schema used in workflows expects single object output (i.e. non-array). All of the
"list" scripts output an array of results, leading to the error below when executed by a workflow. The other
scripts will not produce this error.

`The script output does not validate against the output JSON schema`