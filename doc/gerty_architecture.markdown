Gerty software architecture
===========================

Introduction
------------

Gerty is designed to be a replacement to RANCID software, and much more.
While RANCID is mainly concentrated on router configuration backup, and
there's Cisco in its name, Gerty is different:

*   Generic Telnet/SSH/whatever output processing tool.  
    Router configuration is still the important part of the output, but 
    we can do more.
    
*   Pluggable architecture: some standarrd modules come with the main
    distribution, some modules are distributed as plugins, and the user 
    can add their own modules without messing up with the original files 
    that were installed by Gerty and its plugins.
    
*   Vendor neutrality: we are not concentrarted on Cisco.

*   Support for interactive processing: new CLI commands may depend on the 
    output of previous ones
    
*   Hooks for automatic output validation: you may need to verify the 
    configuration against some inventory databases, check that it conforms to 
    some templates, etc.
    
Gerty is completely written in Perl. Also all custom hooks and 
processing tools are planned to be in Perl.



    
