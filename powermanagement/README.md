# Enable and Disable Power Management on a RHEV 3.6 Hypervisor

## Description
This small script provides the ability to disable and enable the power management of a hypervisor.
The only restriction to this is, that the power management has to be configured well, before using this script.


## Setup Configuration
Open file `pm.sh` and define the variables `API_HOST` and `API_USER`.

Example:
~~~
API_HOST="rhev-m.example.com"
API_USER=admin@internal
~~~

### Setup password
The password for the RHEV-API user is stored in the file `.apipasswd` beside the script `pm.sh`.
Example:
~~~
$: cat .apipasswd
redhat
~~~

For gaining a minimum of security, this file should not be accessible by others than the owner itself.
~~~
chmod 600 .apipasswd
~~~


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
