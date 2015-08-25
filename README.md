In-VM metadata service for pulling dynamic VM info e.g. virtual network status, future planned reboots etc

##“What just happened to my VM?” - In-VM Metadata Service

### Introduction ####

As a service owner that runs on a public cloud, you might already asked or heard the question “what just happened to my VM?”. One of the advantages in running virtual machines on Azure is that we keep your VMs available even when there are unexpected problems or running [planned platform updates](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-planned-maintenance/). For the former, when Azure detects a problem with a node, it proactively moves the VMs to new nodes so they are restored to a running and accessible state. For the latter, some updates do require a reboot to your virtual machines. Although we send [email notification](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-planned-maintenance/#single-instance-configuration-updates) for such events, as a service owner you might want to better prepared for the coming occurrence. However, some services need to know when such event is about to happen. It will allow the services to execute several steps that can minimize and even eliminate the service interruption to its end-users. 

In this post we present the In-VM Metadata service. The service is based on [IETF3927](https://tools.ietf.org/html/rfc3927) that allows a dynamic network configuration within the 169.254/16 prefix that is valid for communication with other VMs connected to the same physical node. 

### How Should I Use It? ###
The in-vm metadata service allows a standard method to pull the maintenance status of that VM by executing the command:
```curl http://169.254.169.254/metadata/v1/InstanceInfo```

The standard results set will include three main attributes, InstanceID, [placement upgrade-domains and placement fault-domains](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-manage-availability/). In case of on-going maintenance activity is about to begin (within 5 minutes) an additional maintenance-event will be added.

Normal Results - 
``` {“ID":"myInstanceVM1","UD":"0","FD":"0"} ```

Results when your VM in about to reboot -
``` {“ID”:”myInstanceVM1","UD":"0","FD":"0","Reboot"} ```

### Why Should I Use it? ###
The service is easy use and available on any OS you choose to run. It will allow a pulling-based mechanism from the VM itself so the Devops team who operates the service can get a near-time status of their VMs. Such indications can help you masking availability issues from your end users and increase the service availability. e.g. basic availability logging or This post will focus on two scenarios one can use the in-vm-metadata service:
1. System logging events - In this example, the service owners would like to track their resources availability by pulling data on regular basis and store it in EventLog (Windows) or syslog (Linux). 
2. Masking reboots from end-users by tracking on-the-spot upcoming reboots and drains traffic from a VM that about to be rebooted. VMs can be excluded from its availability set based on dynamic indication pulled from the in-vm-metadata service.  

####Simple Reboot Logging####
The example below shows how upcoming reboots on an Azure VM can be logged using standard logging, i.e. EventLog for Windows and syslog for Linux.
 
In the following example [IsVmInMaint.ps1](https://github.com/yahavb/AzureComputeInVmNotification/blob/master/samples/IsVmInMaint.ps1) is scheduled to execute every five minutes and log an event in the EventLog in case of a VM reboot is about to happen. 
```
$result=curl http://169.254.169.254/metadata/v1/InstanceInfo | findstr "^Content" | findstr -i “reboot”
if ($result) {Write-EventLog -LogName Application –Source "IsVmInMaint" -EntryType Information –EventID 1 –Message "Incoming VM reboot"}
```
The [IsVmInMaint.sh](https://github.com/yahavb/AzureComputeInVmNotification/blob/master/samples/IsVmInMaint.sh) does the same action as the former but assumed to be registered in crontab to be executed every five minutes and log upcoming reboots event using the Linux syslog. 
``` bash
#!/bin/bash
result=`curl http://169.254.169.254/metadata/v1/InstanceInfo| grep -i reboot`
if [ -n $result ]; then
 `logger Incoming VM reboot`
fi
```
####Masking Reboots from Users####
The example below depicts #2 (Fig. 1), we have a simple distributed application with one tier (availability set) that  is configured to use load balancer that maintain its stickyness based source IP. i.e. client i landed on VM1 (http://myinvmmetadata1.cloudapp.net/) on his first request. All consequent calls will be diverted to VM1 until VM1 will not be available. Other clients will be served by the available VMs based load factor captured by the load balancer. 

![](https://github.com/yahavb/AzureComputeInVmNotification/blob/master/misc/lb.png)

Fig. 2 shows the case where VM1 is under maintenance that might require the service to (1) proactively drain VM1 endpoint http://myinvmmetadata1.cloudapp.net/ from new client sessions (2) exclude VM1 from the available load balancer member, the current endpoints http://myinvmmetadata2.cloudapp.net/ and http://myinvmmetadata3.cloudapp.net/ 

![](https://github.com/yahavb/AzureComputeInVmNotification/blob/master/misc/lb.vm.maint.png)

At that point, the VM that is about to be impacted can execute the command to the load-balancer traffic manager for excluding it from future traffic. Finally, the VM is back and no maintenance activity on the VM. The VM can be added back to the available endpoint pool. 

#####A little more details#####
Adding a VM to a load balancer pool - [Add-AzureEndpoint](https://msdn.microsoft.com/library/azure/dn495300)

Validating an endpoints  - [Get-AzureEndpoint](https://msdn.microsoft.com/library/azure/dn495158)

Removing an endpoint from a load balancer pool - [Remove-AzureEndpoint](https://msdn.microsoft.com/library/azure/dn495161)

###How Does it Work###
The instance metadata server is http server that returns data from a host agent (the node) that receive commands from the main controller component (Fig. 3). 

![](https://github.com/yahavb/AzureComputeInVmNotification/blob/master/misc/arch.png)

When the controller initiate a command on a node, it stored in a repository that remains valid for the duration of the activity i.e. planned maintenance, service healing etc. The following chart is the high level overview of today’s communication framework. The REST Server is the only place the VM can communicate. For the metadata instance server, we use the standard Link-Local addresses i.e. 169.254/16 which is aligned with [RFC3927](https://tools.ietf.org/html/rfc3927).

###What Next###
We are interested in learning more about your scenarios and understand how the In-VM Metadata service can help you achieve it. If you think you wish to see other data entries please drop us a line. 
