# BOSH Windows Stemcell Builder  [![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://slack.cloudfoundry.org)

This repository contains Rake tasks for creating BOSH Windows stemcells for AWS, Azure, GCP, and Openstack

The recommended approach for creating BOSH Windows stemcells for vSphere which can be deployed on [Cloud Foundry BOSH](https://bosh.io), is [`stembuild`](https://github.com/cloudfoundry/stembuild).

[Documentation on how to use `stembuild` can be found here.](https://bosh.io/docs/windows-stemcell-create/)

#### Contributing
Please submit PR's to the `develop` branch

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
rake build:aws                                                                 # Build AWS Stemcell
rake build:azure                                                               # Build Azure Stemcell
rake build:gcp                                                                 # Build GCP Stemcell

rake publish:staging:azure                                                     # Stage an image to the Azure marketplace
rake publish:production:azure                                                  # Publish an image to the Azure marketplace
rake publish:finalize:azure                                                    # Wait for finalizing an image to the Azure marketplace

rake publish:gcp                                                               # Publish an image to GCP
```

#### Running the tests
```
bundle exec rspec
```

Acceptance testing for stemcells should be done with [bosh-windows-acceptance-tests](https://github.com/cloudfoundry/bosh-windows-acceptance-tests)

