# AzureComputeInVmNotification
In-VM metadata service for pulling dynamic VM info e.g. Vnet status, future planned reboots etc

“What just happened to my VM?” - In-VM Metadata Service
-------------------------------------------------------

### Introduction ####

As a service owner that runs on a public cloud, you might already asked or heard the question “what just happened to my VM?”. One of the advantages in running virtual machines on Azure is that we keep your VMs available even when there are unexpected problems or running planned platform updates. For the former, when Azure detects a problem with a node, it proactively moves the VMs to new nodes so they are restored to a running and accessible state. For the latter, some updates do require a reboot to your virtual machines. Although we send email notification for such events, as a service owner you might want to better prepared for the coming occurrence. However, some services need to know when such event is about to happen. It will allow the services to execute several steps that can minimize and even eliminate the service interruption to its end-users. 

In this post we present the In-VM Metadata service. The service is based on IETF 3927 that allows a dynamic network configuration within the 169.254/16 prefix that is valid for communication with other VMs connected to the same physical node. 

### How Should I Use It? ###
The in-vm metadata service allows a standard method to pull the maintenance status of that VM by executing the command:
```curl http://169.254.169.254/metadata/v1/InstanceInfo```

The standard results set will include three main attributes, InstanceID, placement upgrade-domains and placement fault-domains. In case of on-going maintenance activity is about to begin (within 5 minutes) an additional maintenance-event will be added.

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
 
In the following example IsVmInMaint.ps1 is scheduled to execute every five minutes and log an event in the EventLog in case of a VM reboot is about to happen. 
```
$result=curl http://169.254.169.254/metadata/v1/InstanceInfo | findstr "^Content" | findstr -i “reboot”
if ($result) {Write-EventLog -LogName Application –Source "IsVmInMaint" -EntryType Information –EventID 1 –Message "Incoming VM reboot"}
```
The IsVmInMaint.sh does the same action as the former but assumed to be registered in crontab to be executed every five minutes and log upcoming reboots event using the Linux syslog. 
``` bash
#!/bin/bash
result=`curl http://169.254.169.254/metadata/v1/InstanceInfo| grep -i reboot`
if [ -n $result ]; then
 `logger Incoming VM reboot`
fi
```
####Masking Reboots from Users####
The example below depicts #2 (Fig. 1), we have a simple distributed application with one tier (availability set) that  is configured to use load balancer that maintain its stickyness based source IP. i.e. client i landed on VM1 (http://myinvmmetadata1.cloudapp.net/) on his first request. All consequent calls will be diverted to VM1 until VM1 will not be available. Other clients will be served by the available VMs based load factor captured by the load balancer. 













Fig. 2 shows the case where VM1 is under maintenance that might require the service to (1) proactively drain VM1 endpoint http://myinvmmetadata1.cloudapp.net/ from new client sessions

