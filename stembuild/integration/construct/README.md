# Construct Integration Test

Construct Integration tests will use an unprepared Windows VM to test transferring artifacts to the VM.


You can either run these tests using an existing Windows VM or having the test create a VM in vCenter to test on. 

In either case, the following environment variables must be set to access the VM:
* `VM_USERNAME`
* `VM_PASSWORD`

### Using an existing VM
To use an existing Windows VM for the integration tests, WinRM must be enabled on the machine with access provided to the given username and password. The `EXISTING_VM_IP` environment variable is used as an implicit feature flag that a VM exists as well as providing the IP of that VM.
    
### Creating a VM in vCenter
To create a VM in vCenter to use for testing the following environment variables must be set:
* `VM_NAME_PREFIX`
* `VM_FOLDER`
* `NETWORK_GATEWAY`
* `SUBNET_MASK`
* Optionally, you can specify `SKIP_CLEANUP=true` to not remove the created VM after tests have been run

Furthermore, GOVC environment variables must be set to access your VM in vCenter. Please see the following [link] to determine which variables to set and how to format them (https://github.com/vmware/govmomi/tree/master/govc#usage)

At minimum the following will need to be provided:
* `GOVC_URL` 
* `GOVC_DATASTORE`
* `GOVC_NETWORK` 
* `GOVC_RESOURCE_POOL` 
#### Determining source for your VM
The following environment variables must be set depending on where your OVA is stored:
##### Create a VM using a local OVA file
* In this case, `OVA_FILE` must be set
##### Create a VM using an OVA on S3
* `OVA_SOURCE_S3_REGION` 
* `OVA_SOURCE_S3_BUCKET`
* `OVA_SOURCE_S3_FILENAME`
* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

#### Choosing an IP for your VM
##### Create a VM with given IP
* In this case, `USER_PROVIDED_IP` must be set 
##### Create a VM IP chosen from a lock resource pool
In order to create a VM in vCenter with an IP from a lock resource pool, the following environment variables will need to be set:
* `LOCK_PRIVATE_KEY` 
* `IP_POOL_GIT_URI`
* `IP_POOL_NAME` 







