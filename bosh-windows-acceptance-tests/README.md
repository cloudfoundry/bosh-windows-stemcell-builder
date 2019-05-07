# bosh-windows-acceptance-tests

This repo houses tests used to verify Windows Stemcells function as expected.

# Example configuration


These tests are run in the [BOSH Windows Stemcells Pipeline](https://main.bosh-ci.cf-app.com/teams/main/pipelines/windows-stemcells).

You can create a `config.json` file, eg:

```json
{
  "bosh": {
    "ca_cert": "<contents of your bosh director cert, with \n for newlines>",
    "client": "<bosh client name>",
    "client_secret": "<bosh client secret>",
    "target": "<IP of your bosh director>"
  },
  "stemcell_path": "<absolute path to stemcell tgz>",
  "stemcell_os": "<stemcell OS either (windows2012R2 or windows2016)>",
  "az": "<area zone from bosh cloud config>",
  "vm_type": "<vm_type from bosh cloud config>",
  "vm_extensions": "<comma separated string of options, e.g. 50GB_ephemeral_disk>",
  "network": "<network from bosh cloud config>",
  "skip_cleanup": "<skip cleanup - if this is false all unused stemcells are deleted>"
  "skip_ms_update_test": "<skip check-updates errand - if true, it will not test that all Windows updates are installed>",
  "ssh_disabled_by_default": "check ssh daemon default startup type - if true then it checks that the startup type is DISABLED. If false or missing, checks startup type is AUTOMATIC"
}
```

And then run these tests with `CONFIG_JSON=<path-to-config.json> ginkgo`.

The timeout for BOSH commands can be overridden with the BWATS_BOSH_TIMEOUT environment variable.
