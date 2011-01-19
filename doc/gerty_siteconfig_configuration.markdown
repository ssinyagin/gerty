Gerty Siteconfig Configuration
==============================


Introduction
------------

Gerty configurartion constsis of a number of INI files, as follows:

* Job definition file(s)
* Siteconfig file (*siteconfig.ini*)
* Device class definition files

This document describes the structure and attribues contained in
*siteconfig.ini* and the structure of siteconfig directory.



File location and naming
------------------------

The siteconfig file must be named *siteconfig.ini*. It must be located in the 
directory pointed by *siteconfig* attribute in the job definition.

The siteconfig directory may contain the following subdirectories:

*   `devclasses/`: this directory is added to the list of device class 
  definition search paths.
*   `lib/`: this directory is added to Perl library search paths.



File structure
--------------

*siteconfig.ini* consists of one *[siteconfig]* section and one or more 
*[devices ...]* sections. This file defines everything that comprises a site.
A site usually refers to the whole local network or some functional part of it.

The *[siteconfig]* section defines global attributes that are common to the 
whole network.

One or more [devices *name*] sections define device lists with unique names.
These lists are referred to by *devlists* attribute in the job definition.



Attributes in [siteconfig]
------------------------------------

There sre no attributes which are specific to *[siteconfig]* section only.
This section usually contains globally-significant device attributes or their 
defaults (with `-default` suffix).



Mandatory attributes in [devices ...]
-------------------------------------

* __source.type__: defines a Perl class name that handles the list of devices.
  Possible values are: `Gerty::DeviceList::File`, `Gerty::DeviceList::DBI`, or 
  some other types implemented in plugins or in site-specific Perl modules.
  
* __source.fields__: comma-separated list of keywords. The list driver 
  fetches arraus of values, and this parameter defines in which order these 
  values should be interpreted. Valid keywords are: 
  + *SYSNAME*: defines a device name
  + *ADDRESS*: defines an IPv4 or IPv6 address. If not specified, gerty tries 
    to look up the device name in DNS
  + *DEVCLASS*: device class that overrides the default class for this list
  + *DESCRIPTION*: optional free-text description

* __devclass__: default device class assigned to all devices in this list. 
  It may be overwritten by device-specific *DEVCLASS* field.
  


Source type "Gerty::DeviceList::File"
-------------------------------------

This source type implements importing of devices from a file on the disk.
Currently it supports only flat file format. In the future, other formats may 
be added.

For this source type, several attributes are mandatory:

* __source.filename__: fully qualified file name to read the devices from.

* __source.filetype__: defines the kind of data. Supported values: `plain`.

* __source.delimiter__: required for plain file type. Defines a regular 
  expression that is used to split the rows into columns.

Optional attributes:

* __source.comment__: regular expression used to identify a comment in the 
  source file. Default value: `^\#`.



Source type "Gerty::DeviceList::DBI"
-------------------------------------

This source type retrieves the devices from an SQL database.

Mandatory attributes:

* __source.dsn__: defines the database connection string as specified in
Perl DBI documentation

* __source.username__: database user

* __source.password__: database user

* __source.query__: SQL query that is to retrieve the devices and their
properties.




  
  



Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  



