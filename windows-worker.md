- Nested virtualization turned on
- Make sure hard disk >100GB disk space
- Make sure ENV var NUM_VCPUS is not more CPUs than your worker has
(https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/lib/tasks/build/vsphere.rake#L29)

- VMware Workstation
- packer.exe
- ovftool.exe
- tar.exe

- Install ruby
  - ruby 2.3.3
  - gem install bundler
  - cd `bosh-windows-stemcell-builder`
  - `bundle install`
