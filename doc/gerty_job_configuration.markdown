Gerty Job Configuration
=======================


Introduction
------------

Gerty configurartion constsis of a number of INI files, as follows:

* Job definition file(s)
* Siteconfig file (*siteconfig.ini*)
* Device class definition files

This document describes the structure and attribues contained in the Job 
definition file.



File location and naming
------------------------

The job definition file name is given as an argument to the `gerty run` 
command, so its location is completely arbitrary. The file should have *.ini*
extension.

Usually the job definition files are located in *jobs/* subdirectory of the 
siteconfig folder.



File structure
--------------

The job definition file must have one and only section called *[job]*.



Mandatory attributes in [job]
-----------------------------

* __title__: a free-form title describing the job

* __siteconfig__: a full path of *siteconfig* directory

* __devlists__: comma-separated names of device lists that belog to this job.
  Device lists are defined in *siteconfig.ini* in the siteconfig directory.



Optional attributes in [job]
---------------------------

* __description__: additional free-form text describing the job

* __parallel__: the number of parallel processes that would execute this job.
  Default value is 1. The number of processes is automatically reduced to the 
  number of devices if the latter is smaller.

Other attributes in the *[job]* take the highest precedence and overwrite 
the device attributes defined at the siteconfig level.



Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  



