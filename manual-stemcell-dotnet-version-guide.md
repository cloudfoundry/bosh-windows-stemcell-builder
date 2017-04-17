# .NET Versions on Windows 2012R2 Stemcells

Running .NET applications on VMs deployed from Windows 2012R2 stemcells requires that the correct
.NET framework version(s) are installed. Below is a guide to how to enable the desired .NET framework
on the stemcell you build. You can also visit [this link](https://msdn.microsoft.com/en-us/library/bb822049(v=vs.110).aspx)
for some more detailed information.

### .NET 4.6.x and .NET 4.5.x

The latest versions of these .NET frameworks come by default on a fully updated windows2012R2 image.

Run through the manual stemcell build instructions for your IaaS as outlined [here for vSphere](create-manual-vsphere-stemcells.md)
and [here for OpenStack](create-manual-openstack-stemcells.md). If you install all available Windows Updates and run the provisioning
command `Install-CFFeatures` you will enable the latest .NET 4.6.x and .NET 4.5.x frameworks.

### .NET 3.5

**Before** you install Windows Updates, open `powershell` and run the following:

```
Install-WindowsFeature Net-Framework-Core
```

Installing this Windows feature will enable .NET 3.5 and doing so **before** installing Windows Updates
will ensure you install the latest patches and security updates for the framework.
