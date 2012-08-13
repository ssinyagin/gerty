% GERTY(1)

# NAME

gerty - a network job automation tool

# SYNOPSIS

`gerty CMD [options]...`

Available commands:

`run`  
This command runs a job from a job INI file.

# DESCRIPTION

Gerty is a framework for various automation tasks for network
management. It provides a set of access drivers (Telnet, SSH, SNMP,
Netconf, TL1), configuration management, a job manager, and a pluggable
API for customizations.

# COMMON OPTIONS

`--verbose`  
 Print extra diagnostics.

`--debug`  
 Print debugging information.

`--deblvl=N`  
 Set the debug level (Default: 1).
 
# RUNNING JOBS

`gerty run JOB.ini [options]...`

`--nofork`  
Disables parallel execution (equal to "parallel = 1" in Job INI file).

`--expect_debug=0|1|2|3`  
Expect.pm debug level (default: 0).

`--limit=RE`  
Regular expression to limit the job to particular device names.

# SEE ALSO

* _Gerty Software Architecture_
* _Gerty User Guide_
* Gerty documentation for specific attributes




