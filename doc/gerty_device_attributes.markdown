Gerty Device attributes
=======================


Introduction
------------

Each device processed by Gerty is assigned a number of attributes.
The attribute values are derived in a hierarchical manner, as follows:

1. Device classes define the default values.
2. Child device classes may override parents' attributes.
3. If a child inherits from several parents, subsequent parents may 
   override previous parents's attributes.
4. The device list (*[devices XXX]* in *siteconfig.ini*) may override 
   attributes defined in device classes.
5. The *[siteconfig]* section in *siteconfig.ini* may override attributes 
   defined in device lists.
6. The *[job]* section in Job definition file may override attributes defined 
   at the siteconfig level.
7. If the value is not found during previous steps, they are repeated 
   by adding `:default` suffix to the attribute name. This allows 
   setting more specfic values to device lists or classes.


Gerty distribution supplies a number of pre-defined device classes, as follows:

* __Gerty.Default__: all other device classes are expected to inherit from 
  this class. It defines some values needed for normal functioning of 
  command-line processing modules.

* __Gerty.CiscoLike__: defines a command-line processing that is common for 
  many Cisco-like interfaces. Vendor-specific modules may inherit and override 
  its values.

* __Gerty.Cisco__: default class for Cisco IOS devices.



Mandatory attributes
--------------------

Default values are specified in *Gerty.Default.ini*.

* __access-handler__: refers to a Perl module that implements the access to 
  a device. Default value: *Gerty::Access::CLI* -- this module defines a 
  command-line interface suitable for most device vendors.

* __credentials-source__: defines the way Gerty should know the login 
  credentials to access devices. Valid values are: `inline` or a Perl module 
  name. Default is *inline*.

* __command-handler__: refers to a Perl class that processes the CLI
  input/output. Example: *Gerty::CLIHandler::CiscoLike*.

* __output.default-path__: directory path where the output of command actions 
  would be stored if not overwritten by *XXX-path* attribute.



Optional attributes
-------------------

* __do.XXX__: if the value is true, execute the action XXX on the device. 
  Action names are defined by the command handlers, such 
  as *Gerty::CLIHandler::CiscoLike*. 

* __XXX.path__: store the action results in a given directory, instead of the 
  one specified by *output.default-path*

* __XXX.postprocess__: if defined, expected to have a name of a Perl module 
  which is called to process the results of the action.


   
Gerty::Access::CLI access handler
---------------------------------

Default values are specified in *Gerty.Default.ini*.

Mandatory attributes:

* __cli.ssh-port__ [22], __cli.telnet-port__ [23]: TCP ports for SSH 
  and Telnet access.

* __cli.timeout__ [15]: defines the command-line timeout in seconds.

* __cli.initial-prompt__: Regular expression that is used to identify the 
  command-line prompt immediately after logging in. Default: `^.+[\#\>\$]`.

Optional attributes:

* __cli.auth-username__, __cli.auth-password__: login credentials. Mandatory if
  *credentials-source* is set to *inline*.

* __cli.log-dir__: directory where a copy of all CLI output is saved.

* __cli.logfile-timeformat__: (mandatory if *cli.log-dir* is defined) 
  *strftime*-formatted suffix which is added to the output file.
  
* __cli.comment-string__: if the remote side echoes back the entered command,
  it would be prepended with these characters. For example, 
  *Gerty.CiscoLike.ini* defines it as `!!!`.
  
* __admin-mode__: if set to true value, the command handler tries to enter 
  into administrative mode (*enable* in Cisco terms). 

 


Gerty::CLIHandler::Generic command handler
------------------------------------------

This handler implements basic command execution and is designed for being 
inherited by other handlers, such as *Gerty::CLIHandler::CiscoLike*.

Actions:

* __exec-command__: expects the attribute *exec-command* to contain a 
  comma-separated list of commands which would be executed on the device.


  

Gerty::CLIHandler::CiscoLike command handler
--------------------------------------------

Actions:

* __config-backup__: saves the current device configuration in a file.


Default values are specified in *Gerty.CiscoLike.ini*.

Mandatory attributes:

* __user-prompt__: regular expression for user prompt. Default: `^\S+\>`.

* __admin-prompt__: regular expression for enable prompt. Default: `^\S+\#`.

* __admin-mode-command__: command that enters administrative mode. 
  Default: `enable`.

* __init-terminal__: comma-separated list of attributes defining the 
  terminal initialization commands. Default: `pager-off`, and the 
  corresponding command is defined in the attribute *pager-off-command*, set 
  to `terminal length 0`.

* __show-config-command__: command that prints the current device 
  configuration. Default: `show running-config`.


Optional attributes:

* __cli.auth-epassword__: enable password. Not required if the user is 
  automatically privileged.

* __config-exclude__: comma-separated list of attributes. Default: 
  `ntp-clock-period`, and the corresponding attribute 
  *ntp-clock-period-regexp* defines a regular expression. These parameters 
  define the lines which should be removed from the configuration before 
  saving the result.


  
  


  
  

  
 
  



Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  



