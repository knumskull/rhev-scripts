# Enable and Disable Power Management on a RHEV 3.6 Hypervisor

## Description
This small script provides the ability to disable and enable the power management of a hypervisor.
The only restriction to this is, that the power management has to be configured well, before using this script.

## Usage
~~~
usage: pm.sh [status|disable|enable] <hostname>
    status <hostname>  -> print current powermanagement status.
    enable <hostname>  -> enable powermanagement on host <hostname>. 
    disable <hostname> -> disable powermanagement on host <hostname>.
~~~


Examples:
~~~
$ ./pm.sh status hv-01
Powermanagement Status of Host hv-01: OFF

$ ./pm.sh enable hv-01
Enable Powermanagement on Host hv-01 ... ON

$ ./pm.sh disable hv-01
Disable Powermanagement on Host hv-01 ... OFF
~~~


## Disclaimer
There is no warranty on success by using these scripts. You will use these scripts on your own risk.
