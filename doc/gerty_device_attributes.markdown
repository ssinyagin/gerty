Gerty Device Attributes
=======================


Introduction
------------

Each device processed by Gerty is assigned a number of attributes.

There are two types of device attributes in GertyA: additive and normal.

Names of additive attributes start with the plus sign (+). Their values are 
comma-separated lists, and these lists are additively comprised of values 
found on all hierarchy levels: in the class hierarchy, device list, 
siteconfig, and at the job level.

Values of normal attributes are derived in a hierarchical manner, as follows:

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




Mandatory attributes
--------------------

Default values are specified in *Gerty.Default.ini*.

* __access-handler__: refers to a Perl module that implements the access to 
  a device. Default value: *Gerty::CLI::DirectAccess* -- this module defines a 
  command-line interface suitable for most device vendors.

* __credentials-source__: defines the way Gerty should know the login 
  credentials to access devices. Valid values are: `inline` or a Perl module 
  name. Default is *inline*.

* __job.action-handler__: refers to a Perl class that processes the CLI
  input/output. Example: *Gerty::CLI::CiscoLike*.

* __job.output-handler__: defines the Perl class that is used for action 
  output processing. Default: *Gerty::Output::File*.



Optional attributes
-------------------

* __do.XXX__: if the value is true, execute the action XXX on the device. 
  Action names are defined by the command handlers, such 
  as *Gerty::CLI::CiscoLike*. 

* __XXX.path__: store the action results in a given directory, instead of the 
  one specified by *output.default-path*

* __+XXX.postprocess-handlers__: if defined, expected to have a list of Perl
module names which are called to process the results of the action.

* __admin-mode__: if set to true value, the command handler tries to enter 
  into administrative mode (*enable* in Cisco terms).

* __domain-name__: if ADDRESS is missing in device list, gerty tries to
  resolve the device SYSNAME in DNS. If SYSNAME does not contain dots,
  Gerty will try appending the value of `domain-name` for DNS
  resolution.



Gerty::Output::File output handler
----------------------------------

Default values are specified in *Gerty.Default.ini*.

Mandatory attributes:

* __output.default-path__: directory path where the output of command actions 
  would be stored if not overwritten by *XXX.path* attribute.

* __output.failure-suffix__ [failure]: suffix to be used for failure status 
  file names.
  
* __output.success-suffix__ [success]: suffix to be used for success status 
  file names.

Optional attributes:

* __output.default-status-path__: a directory where the action status 
  files would be created. Defaults to the same path as __output.default-path__.

* __output.delete-on-failure__ [0]: if set to true, the previous output
  file is deleted before the action starts.

* __output.suppress-content__: if set to true value, the content of the action
result is not written in the output file. This can be useful when only 
post-processing is required.

   
Gerty::CLI::DirectAccess access handler
---------------------------------------

Default values are specified in *Gerty.Default.ini*.

Mandatory attributes:

* __cli.access-method__: CLI access protocol. Currently supported: `ssh`, 
`telnet`.

* __cli.ssh-protocol__ [2]: Specifies the SSH protocol versions in order
  of preference. Possible values are *1* and *2*. Multiple versions must
  be comma-separated.

* __cli.ssh-port__ [22], __cli.telnet-port__ [23]: TCP ports for SSH 
  and Telnet access.

* __cli.timeout__ [15]: defines the command-line timeout in seconds.

* __cli.initial-prompt__: Regular expression that is used to identify the 
  command-line prompt immediately after logging in. Default: `^.+[\#\>\$]`.

Optional attributes:

* __cli.auth-username__, __cli.auth-password__: login credentials. Mandatory if
  *credentials-source* is set to *inline*.

* __cli.log-dir__: directory where a copy of all CLI output is saved.

* __cli.log-enabled__: if set to true value, CLI output loging is enabled.

* __cli.logfile-timeformat__: (mandatory if *cli.log-dir* is defined) 
  *strftime*-formatted suffix which is added to the output file.
  
* __cli.comment-string__: if the remote side echoes back the entered command,
  it would be prepended with these characters. For example, 
  *Gerty.CiscoLike.ini* defines it as `!!!`.
  
* __cli.cr-before-login__: if set to true, the CLI handler issues a 
  carriage-return before waiting for a login prompt in a Telnet session.
 
 

Gerty::CLI::SSHProxy access handler
-----------------------------------

This access handler connects to an SSH jump-host, and then continues 
with the normal behavior of Gerty::CLI::DirectAccess.

Default values are specified in *Gerty.Default.ini*.

Mandatory attributes:

* __sshproxy.port__ [22]: TCP port for SSH access to the SSH proxy.

* __sshproxy.login-timeout__ [5]: time to expect a shell prompt.

* __sshproxy.ssh-command__ [ssh], __sshproxy.telnet-command__ [telnet]: 
  shell commands to establish a connection from the proxy to the remote host.

* __sshproxy.hostname__: SSH proxy host

* __sshproxy.username__: SSH proxy login

* __sshproxy.password__: SSH proxy password. If public key authentication 
  is used, this attribute must be set to some dummy value.
  


Gerty::CLI::GenericAction command handler
-----------------------------------------

This handler implements basic command execution and is designed for being 
inherited by other handlers, such as *Gerty::CLI::CiscoLike*.

Optional parameters:

* __+cli.command-actions__ (additive): comma-separated list of new action 
  names. Each action (XXX) must be accompanied by a corresponding 
  __XXX.command__ or __XXX.command-N__

* __XXX.multicommand__: if set to a nonzero integer, defines the number of 
  subsequent commands that comprise the action. Each command must be defined 
  in __XXX.command-N__ attribute.

* __+cli.handler-mixins__ (additive): comma-separated list of Perl modules
  that define additional actions and their handlers. 
  See the *Gerty Developer Guide* document for more detais.
  
* __cli.error-regexp__: regular expression that identifies an error message in
   the command output. *Gerty.CiscoLike.ini* defines it as `^\%`
  

Gerty::CLI::CiscoLike command handler
-------------------------------------

Actions:

* __config-backup__: saves the current device configuration in a file.


Default values are specified in *Gerty.CiscoLike.ini*.

Mandatory attributes:

* __cli.user-prompt__: regular expression for user prompt. Default: `^\S+\>`.

* __cli.admin-prompt__: regular expression for enable prompt. 
  Default: `^\S+\#`.

* __cli.admin-mode.command__: command that enters administrative mode. 
  Default: `enable`.

* __cli.init-terminal__: comma-separated list of attributes defining the 
  terminal initialization commands. Default: `pager-off`, and the 
  corresponding command is defined in the attribute *pager-off.command*, set 
  to `terminal length 0`.

* __config-backup.command__: command that prints the current device 
  configuration. Default: `show running-config`.


Optional attributes:

* __cli.auth-epassword__: enable password. Not required if the user is 
  automatically privileged.

* __config-backup.exclude__: comma-separated list of attributes. Default: 
  `ntp-clock-period`, and the corresponding attribute 
  *ntp-clock-period.regexp* defines a regular expression. These parameters 
  define the lines which should be removed from the configuration before 
  saving the result.



Gerty::Netconf::Transport::Expect handler
-----------------------------------------

This is a base class for other NETCONF access handlers. Default values are
specified in *Gerty.Netconf.Default.ini*.

Mandatory attributes:

* __netconf.timeout__ [15]: Netconf processing timeout.

Optional attributes:

* __netconf.log-dir__, __netconf.log-enabled__, __netconf.logfile-timeformat__:
see the description of similar parameters in Gerty::CLI::DirectAccess.


  
Gerty::Netconf::Transport::SSH access handler
---------------------------------------------

This access handler should be used for NETCONF over SSH connections (RFC4742).
Default values are specified in *Gerty.Netconf.Default.ini*.

Mandatory attributes:

* __netconf.ssh-port__ [830]: TCP port number for SSH access.

* __netconf.ssh-subsystem__ [netconf]: SSH subsystem as specified in RFC4742.

* __netconf.ssh-use-password__ [1]: if set to true, public key authentication
is not used and *netconf.auth-password* becomes mandatory. If the attrubute
is set to false, only public key authentication is tried.

* __netconf.auth-password__: user password (only required
if *netconf.ssh-use-password* is set to true).



Gerty::Netconf::ActionHandler
-----------------------------

This action handler provides a basic interface for NETCONF actions.
All actions are implemented in mix-in modules, so at least one mix-in should
be specified.

Mandatory attributes:

* __+netconf.handler-mixins__: additive, comma-separated list of mix-in
modules for NETCONF actions.


  




  
  

  
 
  



Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  



