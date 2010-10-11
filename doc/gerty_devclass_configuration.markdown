Gerty Device Class Configuration
================================


Introduction
------------

Gerty configurartion constsis of a number of INI files, as follows:

* Job definition file(s)
* Siteconfig file (*siteconfig.ini*)
* Device class definition files

This document describes the structure and attribues contained in
device class definition files.



File location and naming
------------------------

Device class definition files are searched in a number of directories.

The device classes that come with Gerty distribution are usually installed 
in `share/devclasses` directory at some standard location like `/usr/local`.
This path is configurable and depends on local server administration policy.

Gerty plugins may add new search paths.

In the siteconfig directory, device classes are searched in `devclasses` 
subdirectory.

The usual search order is first in Gerty installation path, then plugins, and 
finally siteconfig.

Each file must be named exactly as the class name, followed by *.ini* 
extension.



File structure
--------------

The device class definition file must contain one and only section called 
`[devclass *NAME*]` where NAME is the class name.



Optional attributes
-------------------

* __inherit__: a comma-separated list of parent device classes. The parent 
listed last has higher precedence.

* __description__: free-text description of the class.

Other attributes are device attributes, and described in the document: 
*Gerty Device Attributes*.



 
  



Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  



