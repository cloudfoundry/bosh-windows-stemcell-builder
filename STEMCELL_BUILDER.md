### Windows Stemcell Builder Setup

Instructions for setting up a Windows Concourse worker for building vSphere stemcells.

## Host machine requirements
	1. If running in a VM VT-x passthrough must be enabled
	2. At least 200GB of disk space (more is better)

## Software Requirements
	1. VMware Workstation Pro
	  - Add ovftool to the path `C:\Program Files (x86)\VMware\VMware Workstation\ovftool`
	2. [Ruby](https://rubyinstaller.org/)
	  - Make sure Ruby is on the system PATH (aka install for all users)
	  - Bundler `gem install bundler`
	3. [WinSW v2 or greater (WinSW.NET4.exe)](https://github.com/kohsuke/winsw)
	4. [concourse_windows_amd64.exe](http://concourse.ci/downloads.html)
	5. [Packer](https://www.packer.io/downloads.html)
	6. [tar.exe](https://s3.amazonaws.com/bosh-windows-dependencies/tar-1490035387.exe) (?)
	5. Golang (?)

## Install Concourse Worker
	1. Create the following directories: C:\containers, C:\concourse, C:\vmx-data
	2. Move WinSW.NET4.exe to C:\concourse\concourse.exe
	3. Save below configuration as C:\concourse\concourse.xml
	4. Save tsa-public-key.pub and tsa-worker-private-key to C:\concourse directory
	5. Install concourse service using WinSW `concourse.exe install`

```xml
<service>
  <id>concourse</id>
  <name>Concourse</name>
  <description>Concourse Windows worker.</description>
  <startmode>Automatic</startmode>
  <executable>C:\concourse\concourse_windows_amd64.exe</executable>
  <arguments>worker /work-dir C:\containers /tsa-worker-private-key C:\concourse\tsa-worker-private-key /tsa-public-key C:\concourse\tsa-public-key.pub /tsa-host "main.bosh-ci.cf-app.com" /tag "vsphere-windows-worker"
  </arguments>
  <onfailure action="restart" delay="10 sec"/>
  <onfailure action="restart" delay="20 sec"/>
  <logmode>rotate</logmode>
</service>
```

## Registering worker

	If the worker cannot connect to TSA make sure it's IP is allowed through the firewall.
