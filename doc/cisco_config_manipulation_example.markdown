Gerty Example: manipulation of Cisco router configuration
=========================================================

Copyright (c) 2012 Stanislav Sinyagin <ssinyagin@k-open.com>



Introduction
------------

This is a real-life example (company name, addresses and passwords are
screened, addresses are taken from RFC5737) where a company needs to
update about a hundred Cisco routers with new configuration.

With Gerty script as shown below, the company is able to do the job
cleanly, error-free, and in a controlled fashion. A manual change would
definitely bring more errors and troubleshooting costs.

Task description
----------------

The compaany (further referred to as XYZ) has more than a hundred remote
branches, and each one is equipped with a Cisco router acting as a
local DHCP server. The DHCP pool configuration contains the DNS and
Netbios server addresses which need to be changed.

Current configuration:

    ip dhcp pool branch-199
       network 192.0.2.0 255.255.255.0
       domain-name 99.pos.xyz.local
       dns-server 198.51.100.1 198.51.100.2
       default-router 192.0.2.254
       netbios-name-server 198.51.100.1 198.51.100.2

Target configuration (only "dns-server" and "netbios-name-server" changed):

    ip dhcp pool branch-199
       network 192.0.2.0 255.255.255.0
       default-router 192.0.2.254
       domain-name 99.pos.xyz.local
       dns-server 198.51.100.5 198.51.100.2
       netbios-name-server 198.51.100.2 198.51.100.5


Installing the software
-----------------------

This is a CentOS 6.x machine, with EPEL and RPMforge repositories configured.

    yum install -y autoconf automake libtool git

    yum install -y perl-Config-Tiny perl-Config-Any \
     perl-Log-Handler perl-Expect perl-XML-LibXML \
     perl-Net-SNMP perl-DBI

    cd /usr/local/src
    git clone https://github.com/ssinyagin/gerty.git
    cd gerty
    autoreconf
    ./configure --prefix=/opt/gerty
    make
    make install

    cd /usr/local/src
    git clone https://github.com/ssinyagin/gerty-plugins.git
    cd gerty-plugins/gp-cisco
    autoreconf
    ./configure --prefix=/opt/gerty plugconfdir=/opt/gerty/share/gerty/plugconf
    make
    make install


Directory layout
----------------

### /opt/XYZ/dnschange_siteconfig

This directory contains XYZ-specific scripts for Gerty:

* `siteconfig.ini`: defines the common parameters and device lists;

* `devclasses/XYZ.SiteRouter.ini`: specifies Gerty action handlers for
site routers;

* `lib/XYZ/SiteRouter.pm`: the actual Perl script that updates the DHCP
pool attributes;

* `jobs/*.ini`: job files for execution.



### /opt/XYZ/dnschange_data

Here Gerty places the results of the job execution in corresponding
subdirectories:

* `logs/`: telnet logs

* `nodelists/`: lists of devices fo rjob execution

* `output/`: job output results (shows the old pool config and applied
changes)

* `status/`: `*.success` files indicate successful execution,
`*.failure` files indicate faulures and contain the fault messages.




Gerty configuration and scripting
---------------------------------

### siteconfig.ini

Here we define the directory paths, default login credentials (random
results from a password generator in this example). Admin mode is
needed, as we're going to change the router configuration. In this
example, one device list is defined, with the source of device IP
addresses in a plain text file. In real life, most probably a test
delice list would be defined for the first tests.

    [siteconfig]
      datapath = /opt/XYZ/dnschange_data
      output.default-path = ${datapath}/output
      output.default-status-path = ${datapath}/status
      cli.auth-username:default = gerty
      cli.auth-password:default = EiVu7eze
      cli.auth-epassword:default = ohgh3Zoh
      cli.log-enabled = 1
      cli.log-dir = ${datapath}/logs
      admin-mode = 1

    [devices SiteRouters]
      description = "Production site routers"
      source.type = Gerty::DeviceList::File
      source.filename = ${datapath}/nodelists/site_routers
      source.filetype = plain
      source.delimiter = \s*\/\/\s*
      source.fields = SYSNAME
      devclass = XYZ.SiteRouter


### devclasses/XYZ.SiteRouter.ini

The device class defines that we want to use the Cisco IOS action
handler with our own mix-in module.

    [devclass XYZ.SiteRouter]
      inherit = Gerty.CiscoIOS
      cli.access-method = telnet
      +cli.handler-mixins = XYZ::SiteRouter


### lib/XYZ/SiteRouter.pm

This Perl module defines the logic that we want to execute, as defined
in the task description. It analyzes current pool configurations, checks
if anything needs to be changed, and applies the changes. The resulting
JSON object lists the pool configurations and applied changes.

    package XYZ::SiteRouter;

    use strict;
    use warnings;

    use JSON;

    our $action_handlers_registry = {
        'update_dns_addresses' => \&update_dns_addresses,
    };

    our $retrieve_action_handlers = \&retrieve_action_handlers;

    sub retrieve_action_handlers
    {
        my $ahandler = shift;

        return $action_handlers_registry;
    }

    sub update_dns_addresses
    {
        my $ahandler = shift;
        my $action = shift;

        my $target_dns_servers = $ahandler->device_attr('dns_addresses');
        if( not defined( $target_dns_servers ) )
        {
            return {'success' => 0,
                    'content' => 'update_dns_addresses action requires ' .
                        'attribute dns_addresses'};
        }

        my $result = {'success' => 1, 'content' => ''};
        my $cmd_result;

        $cmd_result = $ahandler->exec_command('show running-config');
        if( not $cmd_result->{'success'} )
        {
            return $cmd_result;
        }

        my @config_lines = split(/\n/o, $cmd_result->{'content'});

        my $hostname;
        my %old_pool_cfg;
        my %pool_cfg_changes;

        {
            my $pool_name;
            foreach my $line ( @config_lines )
            {
                if( $line =~ /^hostname\s+(\S+)/o )
                {
                    if( defined($hostname) )
                    {
                        die('hostname is defined twice');
                    }
                    $hostname = $1;
                }
                elsif( $line =~ /^ip\s+dhcp\s+pool\s+(\S+)/o )
                {
                    $pool_name = $1;
                    $old_pool_cfg{$pool_name} = [];
                }
                elsif( defined($pool_name) and $line =~ /^\s+(\S.+\S)\s*$/o )
                {
                    push( @{$old_pool_cfg{$pool_name}}, $1 );
                }
                else
                {
                    $pool_name = undef;
                }

                if( $line =~ /^username\s+/o )
                {
                    # we don't care about the rest of config
                    last;
                }
            }
        }

        my $changes_needed = 0;

        foreach my $pool_name (keys %old_pool_cfg)
        {
            my $dns_servers;
            my $netbios_servers;
            $pool_cfg_changes{$pool_name} = [];

            foreach my $line ( @{$old_pool_cfg{$pool_name}} )
            {
                if( $line =~ /^dns-server\s+(.*)/o )
                {
                    $dns_servers = $1;
                }
                elsif( $line =~ /^netbios-name-server\s(.*)/o )
                {
                    $netbios_servers = $1;
                }
            }

            if( $dns_servers ne $target_dns_servers )
            {
                push(@{$pool_cfg_changes{$pool_name}},
                     'dns-server ' . join(' ', $target_dns_servers));
                $changes_needed = 1;
            }

            if( $netbios_servers ne $target_dns_servers )
            {
                push(@{$pool_cfg_changes{$pool_name}},
                     'netbios-name-server ' . join(' ', $target_dns_servers));
                $changes_needed = 1;
            }
        }

        if( $changes_needed )
        {
            $cmd_result = $ahandler->exec_command('conf t');
            if( not $cmd_result->{'success'} )
            {
                return $cmd_result;
            }

            foreach my $pool_name (keys %pool_cfg_changes)
            {
                if( scalar(@{$pool_cfg_changes{$pool_name}}) > 0 )
                {
                    $cmd_result =
                        $ahandler->exec_command('ip dhcp pool ' . $pool_name);
                    if( not $cmd_result->{'success'} )
                    {
                        return $cmd_result;
                    }

                    foreach my $cmd ( @{$pool_cfg_changes{$pool_name}} )
                    {
                        $cmd_result = $ahandler->exec_command( $cmd );
                        if( not $cmd_result->{'success'} )
                        {
                            return $cmd_result;
                        }
                    }

                    $cmd_result = $ahandler->exec_command('exit');
                    if( not $cmd_result->{'success'} )
                    {
                        return $cmd_result;
                    }
                }
            }

            $cmd_result = $ahandler->exec_command('end');
            if( not $cmd_result->{'success'} )
            {
                return $cmd_result;
            }

            $cmd_result = $ahandler->exec_command('write memory');
            if( not $cmd_result->{'success'} )
            {
                return $cmd_result;
            }
        }

        my $result_data = {'old_config' => \%old_pool_cfg,
                           'changes' => \%pool_cfg_changes};

        $result->{'content'} = to_json($result_data, {utf8 => 1, pretty => 1});

        return $result;
    }

    1;


### jobs/dnsupdate_prod.ini

This job file executes the configuration change for production sites, in
10 parallel processes.

    [job]
      title = Update DNS settings
      siteconfig = /opt/XYZ/dnschange_siteconfig
      devlists = SiteRouters
      parallel = 10
      do.update_dns_addresses = 1
      dns_addresses = 198.51.100.2 198.51.100.5


Job execution
-------------

    cd /opt/XYZ/dnschange_siteconfig
    /opt/gerty/bin/gerty run --verbose jobs/dnsupdate_prod.ini

The execution status, job results, and telnet logs are found in
appropriate subdirectories of the data path.