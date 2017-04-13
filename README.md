# BOSH Windows Stemcell Builder [![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://slack.cloudfoundry.org)

This repo contains a set of scripts for automating the process of building BOSH Windows Stemcells.

#### Dependencies

* [Ruby](https://www.ruby-lang.org/en/downloads/) Latest 2.3.x version
* [Golang](https://golang.org/dl/) Latest 1.8.x compiler
* [Packer](https://www.packer.io/downloads.html) for concourse automation

#### Install

```
gem install bundler
bundle install
```

#### Commands
```
rake build:aws                                                                 # Build AWS Stemcell
rake build:azure                                                               # Build Azure Stemcell
rake build:gcp                                                                 # Build GCP Stemcell
rake build:vsphere                                                             # Build VSphere Stemcell
rake build:vsphere_add_updates                                                 # Apply Windows Updates for VMX

rake package:agent                                                             # Package BOSH Agent and dependencies into agent.zip
rake package:bwats                                                             # package bosh-windows-acceptance-tests (BWATS) config.json
rake package:psmodules                                                         # Package BOSH psmodules into bosh-psmodules.zip
rake package:vsphere_ova[ova_file_name,output_directory,version,updates_path]  # Package VSphere OVA files into Stemcells

rake publish:staging:azure                                                     # Stage an image to the Azure marketplace
rake publish:production:azure                                                  # Publish an image to the Azure marketplace
rake publish:finalize:azure                                                    # Wait for finalizing an image to the Azure marketplace

rake publish:gcp                                                               # Publish an image to GCP

rake run:bwats[iaas]                                                           # Run bosh-windows-acceptance-tests (BWATS)
```

Instructions for building a manual stemcell for vSphere can be found in the [manual instructions](create-manual-vsphere-stemcells.md).

#### Running the tests
```
bundle exec rspec
```

### Testing stemcell with [bosh-windows-acceptance-tests](https://github.com/cloudfoundry-incubator/bosh-windows-acceptance-tests)

##### Requirements

* Latest stable [bosh-cli](https://bosh.io/docs/cli-v2.html)
* [Golang](https://golang.org/dl/) Latest 1.8.x compiler

Set the following environment variables:

##### [bosh-cli](https://github.com/cloudfoundry/bosh-cli) environment variables
- BOSH_TARGET: IP of your BOSH director
- BOSH_CLIENT:
- BOSH_CLIENT_SECRET:
- BOSH_CA_CERT: (not a file name, but the actual cert itself)
- BOSH_UUID:

##### Stemcell to test
- STEMCELL_PATH: Path to stemcell tarball

##### Match with [cloud config](https://bosh.io/docs/cloud-config.html)
- AZ:
- VM_TYPE:
- VM_EXTENSIONS:
- NETWORK:

Run BWATS:

```
rake package:bwats
rake run:bwats["vsphere"]
```
