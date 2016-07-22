
### VMware ESXI

#### Prerequisites

1. [Enable SSH on VMware VMESXI](http://www.thomasmaurer.ch/2014/01/enable-ssh-on-vmware-esxi-5-5/)
2. Execute: `esxcli system settings advanced set -o /Net/GuestIPHack -i 1`
3. Ensure VNC is enabled and not blocked by firewall ([reference](https://www.netiq.com/documentation/cloudmanager22/ncm22_reference/data/bxzaz5n.html)):
  1. Navigate to: *Home > Inventory > Hosts and Clusters*.
  2. In the Hosts/Clusters tree view, select the ESXi host name that represents the server you want to open for VNC access
  3. Select the Manage tab, select Settings then Security Profile
  4. In the Firewall section, select the "Edit..." link to display the Firewall properties
  5. In the dialog box, scroll to and select GDB Server, then click OK.

Select the Configuration tab, locate and open the Software list box, then select Security Profile

4. Install `ovftool` if the format of the exported virtual machine is `ovf`

### Configuration

1. Create cache directory in remote datastore (???)

### TODO

## Requrired

1. Clean Temp directories

Other:
* Run compact!
* Make sure updates are disabled

## Nice to have

1. Remove 'packer-vmware-iso' orphaned vm
2. Figure out what vmx fields we are missing from the ESXi, it seems that VMs are missing features found on VMs created directly through vSphere and Fusion.  A consequence of this is that the outputted .ova files do not work with Fusion.
3. [Clean Up the WinSxS Folder](https://technet.microsoft.com/en-us/library/dn251565.aspx)

## Pipeline Setup

* Windows Updates: We update our pipeline and run tests before triggering customer pipelines.
* Disk Size: 40GB is recommended and tested, updates take over 20GB (and will fail).

## Packer 

* `winrm_host` does not currently work on Packer, we have an open [PR](https://github.com/mitchellh/packer/pull/3738) to fix the issue.  Additionally, as of 2016-07-20 the `master` branch of Packer is broken on `ESXi`.  With our changes we were able to successfully build the stemcell using [9c9f8cd](https://github.com/mitchellh/packer/commit/9c9f8cd45160192587a90e95413aaa26fc21b762).
