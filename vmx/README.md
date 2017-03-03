### VMware ESXI Setup

#### Prerequisites

1. [Enable SSH on VMware VMESXI](http://www.thomasmaurer.ch/2014/01/enable-ssh-on-vmware-esxi-5-5/)
2. Execute: `esxcli system settings advanced set -o /Net/GuestIPHack -i 1`
3. Ensure `VNC` is enabled and not blocked by firewall ([reference](https://www.netiq.com/documentation/cloudmanager22/ncm22_reference/data/bxzaz5n.html)):
  1. Navigate to: *Home > Inventory > Hosts and Clusters*.
  2. In the Hosts/Clusters tree view, select the ESXi host name that represents the server you want to open for `VNC` access
  3. Select the Manage tab, select Settings then Security Profile
  4. In the Firewall section, select the "Edit..." link to display the Firewall properties
  5. In the dialog box, scroll to and select GDB Server, then click OK.

#### Notes

If the build fails, manual deletion of the `packer-vmware-iso` VM and `packer-vmware-iso` datastore directory may be required.
