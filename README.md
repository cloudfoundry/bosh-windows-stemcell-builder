# BOSH Windows Stemcell Builder (DEPRECATED September 2020) [![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://slack.cloudfoundry.org)

BOSH Windows Stemcell Builder will be deprecated by September 2020. The recommended approach for creating local BOSH Windows stemcells which can be deployed on [Cloud Foundry BOSH](https://bosh.io), is [`stembuild`](https://github.com/cloudfoundry/stembuild).

[Documentation on how to use `stembuild` can be found here.](https://bosh.io/docs/windows-stemcell-create/)

---

This repo contains a set of scripts for automating the process of building BOSH Windows Stemcells.

#### Contributing
Please submit PR's to the `develop` branch

#### Dependencies

* [Ruby](https://www.ruby-lang.org/en/downloads/) Latest 2.3.x version
* [Golang](https://golang.org/dl/) Latest 1.12.x compiler
* [Packer](https://www.packer.io/downloads.html) for concourse automation
* [Win32-OpenSSH](https://github.com/PowerShell/Win32-OpenSSH) Release [v0.0.18.0](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/v0.0.18.0) is tested.

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

rake package:vsphere_ova[ova_file_name,output_directory,version,updates_path]  # Package VSphere OVA files into Stemcells

rake publish:staging:azure                                                     # Stage an image to the Azure marketplace
rake publish:production:azure                                                  # Publish an image to the Azure marketplace
rake publish:finalize:azure                                                    # Wait for finalizing an image to the Azure marketplace

rake publish:gcp                                                               # Publish an image to GCP
```

In Concourse see [Greenhouse CI](https://github.com/cloudfoundry/greenhouse-ci/tree/master/bosh-windows-stemcell-builder) for required environment variables for these tasks. For example, for `rake build:vsphere` refer to this [task.yml](https://github.com/cloudfoundry/greenhouse-ci/blob/master/bosh-windows-stemcell-builder/create-vsphere-stemcell-from-vmx/task.yml).

Instructions for building a manual stemcell for vSphere can be found in the [wiki](https://github.com/cloudfoundry/bosh-windows-stemcell-builder/wiki/Creating-a-vSphere-Windows-Stemcell).

#### Running the tests
```
bundler exec rspec
```

Acceptance testing for stemcells should be done with [bosh-windows-acceptance-tests](https://github.com/cloudfoundry/bosh-windows-acceptance-tests)

