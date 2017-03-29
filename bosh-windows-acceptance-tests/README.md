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
    "target": "<IP of your bosh director>",
    "uuid": "<UUID of your bosh director>"
  },
  "stemcell_path": "<absolute path to stemcell tgz>",
  "az": "<area zone from bosh cloud config>",
  "vm_type": "<vm_type from bosh cloud config>",
  "network": "<network from bosh cloud config>"
}
```

And then run these tests with `CONFIG_JSON=<path-to-config.json> ginkgo`.
