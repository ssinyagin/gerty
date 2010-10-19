Gerty User Guide
================

Introduction
------------

### Where the name comes from

GERTY is a character in Duncan Jones' "Moon" film. Gerty is a robot,
a very helpful one, speaking with Kevin Spacey's voice. That film is one of
the best sci-fi movies in the recent past. Gerty helps a human, even if it 
knows that that human is helpless :)

### Purpose

Every network administrator, sooner or later, needs to execute some repetitive
tasks with the network devices. This usually includes configuration backup, 
validation and verification, also some site-specific reports, and also 
massive configuration updates, such as access list changes.
For large networks, a massive software upgrade is also quite typical task.

These administrative tasks are usually approached in various fashions, 
for example:

* Cisco Works software is quite helpful in administering Cisco devices.
  It automates the periodic configuration backup, software upgrades, and 
  also allows to execute batch configuration jobs on multiple devices.
  Drawbacks: 1) unusable in multivendor environments; 2) generally slow 
  and not always stable, especially with large networks.

* Some commercial software packages allow automation of many administrative 
  tasks. These packages are usually quite expensive, and also every new 
  feature request takes forever and costs a fortune.

* RANCID is a free and open-source software by Shrubbery Networks.
  At the moment it's one of the most popular packages for automatic 
  configuration backup. It's a painful experience for anyone trying to add 
  new features to RANCID, mainly because of poor design, lots of duplicate 
  and redundant code, and nontrivial debugging. Also the contributions
  from other developers are almost never added into the main distribution.

* Quite often the local administrators develop their own scripts for those 
  tasks. In some rare cases those scripts are well documented and maintained, 
  and can be re-used when the author leaves the job.

Gerty is different:

* It provides a modular framework designed to automate administrative tasks.

* It is not oriented to one specific task or vendor. Every task that needs 
  some kind of automation should be possible with Gerty.

* Anyone can create and maintain their own plugin package for Gerty. Thic may 
  include public packages useful for everyone, or some site-specific features,
  not distributed outside of a company.

* New Perl modules can be added even without any packaging effort: simply 
  locate them in your siteconfig hierarchy where Gerty can find them.

* Gerty provides multiple ways to arrange your device lists and device classes.
  It is up to the local administrator to choose the most suitable data 
  structure.

* Any Perl module that comes with Gerty can be replaced or extended with your
  own code. Also the package installer will not break it, provided that you
  follow some simple rules.

* The source code is located in a Github.com repository. This site enables
  great ways of collaboration. Anyone can fork the main project, add their
  changes to the code, and then invite the maintainer for a merge.
  The only difficulty is that one has to learn how to work with Git
  (read "Pro Git" or some other book).



Organising Siteconfig
---------------------

### Planning the site

*Siteconfig* is a directory that stores all the information related to Gerty's
work in the local network. It has some pre-defined components where Gerty 
would search for information. Generally its contents are quite stable 
and it's useful to put the whole siteconfig into a local version control
system, such as Subversion or Git.

The results of Gerty's work, such as router configurations, can also be stored 
inside Siteconfig, although it's recommended to keep the configuration and 
the data separately.

This guide will use `/opt/gerty/Company` as a siteconfig directory, and 
`/srv/gerty` as the path for all produced data. Here "Company" stands for your 
local network name.

Before arranging the siteconfig, the administrator needs to address some
questions, such as:

* What is the network scope for Gerty?

* Which authentication credentials will be used? Are they always the same 
  thoughout the network?

* How do we group the devices? By network role, by hardware type, 
  by georaphic location? This grouping should be convenient for the current
  network structure, and also it should sustain further network growth.

* What is our inventory system? How can we extract the data (SQL, file export)?
  Should we maintain our own, manually-edited device lists?

Usually it's sufficient to have one siteconfig directory on a server, 
although it's not limited in any way. For example, the server may have two 
siteconfig directories: one for testing, and the other one for productive use.


### siteconfig.ini

The siteconfig directory should contain at least one file: `siteconfig.ini`.
This file defines the network scope for Gerty: its main purpose is to define 
device lists and some global parameters.

The section `[siteconfig]` may contain device attributes that are common for
the whole network. See the *Gerty Device Attributes* document for detailed
information about device attributes and rules of inheritance. 

The following example sets the default access method to SSH and defines a 
variable `datapath` for data storage path. We use the `:default` suffix 
in `cli.access-method` in order to allow the device lists or device classes 
to override this value. Also we will refer to `datapath` variable everywhere 
in further configuration. Its value will be eventually overwritten into
`/srv/gerty-test` in our test job. In our example, all devices are accessed
with the same login credentials, except for the CPE devices.

    [siteconfig]
      cli.access-method:default = ssh
      datapath = /srv/gerty
      output.default-path = ${datapath}/output
      output.default-status-path = ${datapath}/status
      cli.auth-username:default = gerty
      cli.auth-password:default = eeDie6louj
      cli.auth-epassword:default = Ieyei5ofej


The rest of `siteconfig.ini` should consist of device lists. A device list is a
logical grouping of your network devices. In easiest case, all members of a 
list are devices of the same purpose and hardware type. Also a list may
contain devices of the same purpose, but different hardware (for example, 
Cisco and Juniper MPLS-PE routers).

Individual properties of each device type are defined in device classes.
For simple tasks, devices can be assigned the standard Gerty classes, such as 
`Gerty.CiscoIOS`. In other cases, it is necessary to define your own device 
classes and subclass the standard ones. In our example, we define the following
device classes:

* `Company.MPLS.PE.JuniperMX`: Juniper MPLS-PE routers
* `Company.MPLS.PE.Cisco7600`: Cisco MPLS-PE routers
* `Company.Access.CPE.Cisco870`: Customer-premises equipment

Each device list has a default device class, and also each individual member 
can be assigned to some other device class. For homogenious networks, it 
should be sufficient to have just one device class per device list. In 
other cases, it might be easier to assign each device an individual class, 
and have the whole network in one device list: this way it might be easier
for importing from the inventory system.

The following examples use file-based device lists. *Database import will 
be implemented later. Probably also Excel file import would be added*. 

When importing the device list from a flat file, each device is expected to be
on a separate line. Within each line of text, the local administrator is free
to decide on the format. In the following example, the fields are separated 
by double slashes, and Gerty expects the system name to come first, then
optional IP address, and then description. *Currently device description
is not used anywhere*. Alternatively the administrator may want to specify
the device class in the import file, or some other custom property.

    [devices mpls-pe.cisco7600]
      description = "Cisco 7600 series as MPLS PE routers"
      source.type = Gerty::DeviceList::File
      source.filename = ${datapath}/nodelists/mpls-pe.cisco7600
      source.filetype = plain
      source.delimiter = \s*\/\/\s*
      source.fields = SYSNAME, ADDRESS, DESCRIPTION
      devclass = Company.MPLS.PE.Cisco7600

If *ADDRESS* field is empty, Gerty tries to resolve the system name in DNS.


### Actions

Gerty behavior is determined by *actions*. In our example, we specify the 
actions in our device classes, although in simple cases the actions may 
also be specified in siteconfig.ini or in the job definition file.

Actions are defined in CLI handler Perl modules. See the *Gerty Device 
Attributes* document for a complete list of actions implemented in Gerty
distributions. New actions, such as interactive CLI scripts for your specific 
tasks, can be defined in your site-specific Perl modules.

The `Gerty::CLIHandler::Generic` CLI handler module allows you to define new 
simple actions consisting of one or several CLI commands.

The following example defines a new generic device class and a few useful
commands for Cisco IOS:

  ; File: /opt/gerty/Company/devclasses/Company.IOSActions.ini  
  [devclass Company.IOSActions]
    cli.command-actions = ios.sh-ospfnbr, ios.sh-qos, ios.sh-intf
    ios.sh-ospfnbr.command = show ip ospf neighbor
    ios.sh-qos.command = show policy-map interface
    ios.sh-intf.command = show interface


### Device classes

Site-specific device classes are expected to be defined in the `devclasses/`
subdirectory of siteconfig. Each class is defined in a separate file named
exactly after the class name, with `.ini` file extension. Each class 
definition file must contain exactly one section named 
`[devclass XXX]` where XXX is the class name.

The following example sets different credentials for CPE devices, and a
couple of "show" commands. Also it specifies explicitly where the results of
these commands should be stored:

  ; File: /opt/gerty/Company/devclasses/Company.Access.CPE.Cisco870.ini  
  [devclass Company.Access.CPE.Cisco870]
    inherit = Gerty.CiscoIOS, Company.IOSActions
    do.ios.sh-qos = 1
    ios.sh-qos.path = ${datapath}/output/cpe/qos
    do.ios.sh-intf = 1
    ios.sh-intf.path = ${datapath}/output/cpe/interfaces
    do.config-backup = 1
    config-backup.path = ${datapath}/output/cpe/config


### Job definitions

Job definition files can be stored anywhere in the filesystem, but for 
consistency they are recommended to be in `jobs` subdirectory of siteconfig.

A job file must contain three mandatory attributes: `title`, `siteconfig`, and 
`devlists`. See the *Gerty Job Configuration* document for precise details.

A job file may also specify device attributes. These values would take the
highest precedence. So you can create a job file which allows you to test some 
new features without altering `siteconfig.ini`.

The following example defines a job for all CPE devices. It tests a new 
interactive action and accesses them with 10 parralel sessions. 
Also it specifies an alternative path for output:

    ; File: /opt/gerty/Company/jobs/cpe_test_01.ini
    [job]
      title = CPE interactive diagnostics test
      parallel = 10
      siteconfig = /opt/gerty/Company
      devlists = access.cpe.cisco
      datapath = /srv/gerty-test
    
      ; (not implemented yet) load Perl module: 
      ; /opt/gerty/Company/lib/Company/CPEInteractiveDiagnostics.pm
      ; this module would define a new action, "company.intrdiags"
      cli.extra-handlers = Company::CPEInteractiveDiagnostics
      do.company.intrdiags = 1
      company.intrdiags.path =  ${datapath}/output/cpe/diag


### Job execution

As soon as the job definition and siteconfig are ready, you may run
Gerty and see see the results.

First, try it on only one device in verbose mode:

    gerty run /opt/gerty/Company/jobs/cpe_test_01.ini --verbose --limit=cpe001

If something goes wrong, replace `--verbose` with `--debug` option and analyze
the output.

When everything seems right, execute the job for all devices:

    gerty run /opt/gerty/Company/jobs/cpe_test_01.ini

For each device and every action, there will be a status file in 
`/srv/gerty-test/status` directory. For successfully executed actions there 
will be empty `*.success` files, and for failed ones, the files `*.failure` 
would contain the error message.



Extending Gerty with your own Perl modules
------------------------------------------

See the *Gerty Developer Guide* document for more detais (*not written yet*).















Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  
