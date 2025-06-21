# BOSH Windows Stemcell Builder

This repository contains Rake tasks for creating BOSH Windows stemcells for AWS, Azure, GCP, and Openstack

The recommended approach for creating BOSH Windows stemcells for vSphere which can be deployed on [Cloud Foundry BOSH](https://bosh.io), is [`stembuild`](https://github.com/cloudfoundry/stembuild).

[Documentation on how to use `stembuild` can be found here.](https://bosh.io/docs/windows-stemcell-create/)

#### Dependencies

* [Ruby](https://www.ruby-lang.org/en/downloads/) - see `.ruby-version`
* [Golang](https://golang.org/dl/) - latest
* [Packer](https://www.packer.io/downloads.html) - for image creation
* [Win32-OpenSSH](https://github.com/PowerShell/Win32-OpenSSH) Release [v0.0.18.0](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/v0.0.18.0) is tested.

#### Install

```
gem install bundler
bundle install
```

#### Commands
```
rake build:aws                  # Build AWS Stemcell
rake build:azure                # Build Azure Stemcell
rake build:gcp                  # Build GCP Stemcell

rake publish:staging:azure      # Stage an image to the Azure marketplace
rake publish:production:azure   # Publish an image to the Azure marketplace
rake publish:finalize:azure     # Wait for finalizing an image to the Azure marketplace

rake publish:gcp                # Publish an image to GCP
```

#### Running the tests
```
bundle exec rspec
```

Acceptance testing for stemcells is done via [acceptance_test](acceptance_test)

## Relocated Documentation
- azure-light-stemcell.md
  - https://github.com/cloudfoundry/bosh-windows-stemcell-builder/wiki/Using-the-Azure-Light-Stemcell
- create-manual-openstack-stemcells.md
  - https://github.com/cloudfoundry/bosh-windows-stemcell-builder/wiki/Create-Manual-OpenStack-Stemcells
- manual-stemcell-dotnet-version-guide.md
  - https://github.com/cloudfoundry/bosh-windows-stemcell-builder/wiki/Manual-Stemcell-DotNet-Version-Guide
- with-concourse.md
  - https://github.com/cloudfoundry/bosh-windows-stemcell-builder/wiki/Windows-Worker-and-Concourse-Setup
