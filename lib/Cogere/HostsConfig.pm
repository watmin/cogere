package Cogere::HostsConfig;

use strict;
use warnings;

use Cogere::Util;

use YAML::Tiny;
use List::MoreUtils qw/uniq/;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_config_file;
fieldhash my %_hosts_config;
fieldhash my %_cogere_config;

sub new {
    my ( $class, %args ) = @_;

    defined $args{'hosts-config'}  or croak "Failed to provide hosts config to Cogere::HostsConfig";
    defined $args{'cogere-config'} or croak "Failed to provide cogere config to Cogere::HostsConfig";

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->_config_file( $args{'hosts-config'} );
    $self->_cogere_config( $args{'cogere-config'} );

    return $self;
}

sub get_host {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname to Cogere::HostsConfig::get_host";

    my $host = $self->_hosts_config->{'hosts'}{$hostname};
    if ( !$host ) {
        return;
    }

    my $keys_path = $self->_cogere_config->keys_path;

    $host->{'private-key'} = "$keys_path/$hostname";
    $host->{'public-key'}  = "$keys_path/$hostname.pub";

    return $host;
}

sub get_group {
    my ( $self, $groupname ) = @_;

    defined $groupname or croak "Failed to provide group name to Cogere::HostsConfig::get_group";

    my $group = $self->_hosts_config->{'groups'}{$groupname};

    return $group;
}

sub get_all_hosts {
    my ($self) = @_;

    my $hosts_ref = $self->_hosts_config->{'hosts'};
    $hosts_ref or croak "No hosts configured.";

    my @hosts = keys %{ $hosts_ref };

    return @hosts;
}

sub get_all_groups {
    my ($self) = @_;

    my @groups = keys %{ $self->_hosts_config->{'groups'} };

    return @groups;
}

sub get_members {
    my ( $self, $groupname ) = @_;

    defined $groupname or croak "Failed to provide group name to Cogere::HostsConfig::get_members";

    my $members_ref = $self->_hosts_config->{'groups'}{$groupname};
    $members_ref or croak "Group '$groupname' not found.";

    my @members = @{ $members_ref };

    return @members;
}

sub new_host {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname to Cogere::HostsConfig::new_host";
    defined $args{'password'} or croak "Failed to provide password to Cogere::HostsConfig::new_host";
    defined $args{'remoteid'} or croak "Failed to provide remote ID to Cogere::HostsConfig::new_host";

    my $yaml = $self->_yaml;

    my $host = {
        'password' => $args{'password'},
        'remoteid' => $args{'remoteid'},
    };

    if ( defined $args{'username'} ) {
        $host->{'username'} = $args{'username'};
    }

    if ( defined $args{'ipaddr'} ) {
        $host->{'ipaddr'} = $args{'ipaddr'};
    }

    if ( defined $args{'port'} ) {
        $host->{'port'} = $args{'port'};
    }

    $yaml->[0]{'hosts'}{$args{'hostname'}} = $host;
    $yaml->write($self->_config_file);

    return;
}

sub del_host {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname to Cogere::HostsConfig::del_host";

    $self->validate_hosts( $args{'hostname'} );

    if ( !defined $args{'preserve-groups'} ) {
        $self->_leave_all_groups( $args{'hostname'} );
    }

    my $yaml = $self->_yaml;
    delete $yaml->[0]{'hosts'}{$args{'hostname'}};
    $yaml->write($self->_config_file);

    return;
}

sub change_ipaddr {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname to Cogere::HostsConfig::change_ipaddr";
    defined $args{'ipaddr'}   or croak "Failed to provide IP address to Cogere::HostsConfig::change_ipaddr";

    $self->validate_hosts( $args{'hostname'} );

    my $yaml = $self->_yaml;
    $yaml->[0]{'hosts'}{$args{'hostname'}}{'ipaddr'} = $args{'ipaddr'};
    $yaml->write($self->_config_file);

    return;
}

sub cleanup_host {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname to Cogere::HostsConfig::cleanup_host";

    $self->_leave_all_groups(%args);
    $self->del_host(%args);

    return;
}

sub new_group {
    my ( $self, %args ) = @_;

    defined $args{'groups'} or croak "Failed to provide group name to Cogere::HostsConfig::new_group";
    defined $args{'hosts'}  or croak "Failed to provide hosts to Cogere::HostsConfig::new_group";

    my @dirty_groups = @{ $args{'groups'} };
    my @dirty_hosts  = @{ $args{'hosts'} };
    my @groups       = $self->dedup(@dirty_groups);
    my @hosts        = $self->dedup(@dirty_hosts);
    $self->validate_hosts(@hosts);

    my $yaml = $self->_yaml;

    for my $group (@groups) {
        if ( $self->get_group($group) ) {
            carp "The group '$group' is already configured. Join or delete '$group'";
            next;
        }

        $yaml->[0]{'groups'}{$group} = [@hosts];
    }

    $yaml->write($self->_config_file);
    printf "Successfully created groups: '%s' with hosts: '%s'\n", join( ', ', @groups ), join( ', ', @hosts );

    return;
}

sub del_group {
    my ( $self, %args ) = @_;

    defined $args{'groups'} or croak "Failed to provide group name to Cogere::HostsConfig::del_group";

    my @dirty_groups = @{ $args{'groups'} };
    my @groups       = $self->dedup(@dirty_groups);
    $self->validate_groups(@groups);

    my $yaml = $self->_yaml;

    for my $group (@groups) {
        delete $yaml->[0]{'groups'}{$group};
    }

    $yaml->write($self->_config_file);
    printf "Successfully removed groups: '%s'\n", join( ', ', @groups );

    return;
}

sub join_group {
    my ( $self, %args ) = @_;

    defined $args{'groups'} or croak "Failed to provide group name to Cogere::HostsConfig::join_group";
    defined $args{'hosts'}  or croak "Failed to provide hosts to Cogere::HostsConfig::join_group";

    my @dirty_groups = @{ $args{'groups'} };
    my @dirty_hosts  = @{ $args{'hosts'} };
    my @groups       = $self->dedup(@dirty_groups);
    my @hosts        = $self->dedup(@dirty_hosts);

    $self->validate_groups(@groups);
    $self->validate_hosts(@hosts);

    my $yaml = $self->_yaml;

    for my $group (@groups) {
        my @members = $self->get_members($group);

        for my $host (@hosts) {
            next if grep { $_ eq $host } @members;
            push @members, $host
        }

        $yaml->[0]{'groups'}{$group} = [@members];
    }

    $yaml->write($self->_config_file);
    printf "Successfully added hosts: '%s' to groups: '%s'\n", join( ', ', @hosts ), join( ', ', @groups );

    return;
}

sub leave_group {
    my ( $self, %args ) = @_;

    defined $args{'groups'} or croak "Failed to provide group name to Cogere::HostsConfig::leave_group";
    defined $args{'hosts'}  or croak "Failed to provide hosts to Cogere::HostsConfig::leave_group";

    my @dirty_groups = @{ $args{'groups'} };
    my @dirty_hosts  = @{ $args{'hosts'} };
    my @groups       = $self->dedup(@dirty_groups);
    my @hosts        = $self->dedup(@dirty_hosts);

    $self->validate_groups(@groups);
    $self->validate_hosts(@hosts);

    my $yaml = $self->_yaml;

    for my $group (@groups) {
        my @members = $self->get_members($group);

        for my $host (@hosts) {
            @members = grep { $_ ne $host } @members;
        }

        $yaml->[0]{'groups'}{$group} = [@members];

        if ( !scalar @{ $yaml->[0]{'groups'}{$group} } ) {
            delete $yaml->[0]{'groups'}{$group};
        }
    }

    $yaml->write($self->_config_file);
    printf "Successfully removed hosts: '%s' from groups: '%s'\n", join( ', ', @hosts ), join( ', ', @groups );

    return;
}

sub validate_hosts {
    my ( $self, @hosts ) = @_;

    for my $host (@hosts) {
        $self->get_host($host) or croak "Invalid host '$host'.";
    }

    return;
}

sub validate_groups {
    my ( $self, @groups ) = @_;

    for my $group (@groups) {
        $self->get_group($group) or croak "Invalid group '$group'.";
    }

    return;
}

sub dedup {
    my ( $self, @targets ) = @_;

    @targets = uniq @targets;

    return @targets;
}

sub update {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";

    my $yaml = $self->_yaml;

    if ( defined $args{'username'} ) {
        $yaml->[0]->{'hosts'}{$args{'hostname'}}{'username'} = $args{'username'};
    }

    if ( defined $args{'ipaddr'} ) {
        $yaml->[0]->{'hosts'}{$args{'hostname'}}{'ipaddr'} = $args{'ipaddr'};
    }

    if ( defined $args{'port'} ) {
        $yaml->[0]->{'hosts'}{$args{'hostname'}}{'port'} = $args{'port'};
    }

    $yaml->write($self->_config_file);

    return;
}

sub _config_file {
    my ( $self, $config_file ) = @_;

    if ( !defined $_config_file{$self} and defined $config_file ) {
        croak "Hosts configuration file '$config_file' not found: $!" if !-f $config_file;
        $_config_file{$self} = $config_file;
    }
    elsif ( defined $_config_file{$self} and defined $config_file ) {
        carp "Host configuration already defined.";
    }

    return $_config_file{$self};
}

sub _cogere_config {
    my ( $self, $cogere_config ) = @_;

    if ( !defined $_cogere_config{$self} and defined $cogere_config ) {
        $_cogere_config{$self} = $cogere_config;
    }
    elsif ( defined $_cogere_config{$self} and defined $cogere_config ) {
        carp "Cogere::HostsConfig'g Cogere::Config already defined.";
    }

    return $_cogere_config{$self};
}

sub _yaml {
    my ($self) = @_;

    my $yaml = YAML::Tiny->read($self->_config_file)
      or croak "Cogere::HostsConfig failed to parse '${\$self->_config_file}': $!\n";

    return $yaml;
}

sub _hosts_config {
    my ($self) = @_;

    my $yaml = $self->_yaml;

    my $hosts_config = $yaml->[0];

    if ( !$hosts_config ) {
        $self->_fresh_hosts_config;
        $hosts_config = $self->_hosts_config;
    }

    return $hosts_config;
}

sub _leave_all_groups {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname to Cogere::HostsConfig::_leave_all_groups";

    my @groups = $self->get_all_groups;

    for my $group (@groups) {
        my @members = $self->get_members($group);
        if ( grep { $_ eq $hostname } @members ) {
            $self->leave_group(
                'groups' => [$group],
                'hosts'  => [$hostname],
            );
        }
    }

    return;
}

sub _fresh_hosts_config {
    my ($self) = @_;

    my $yaml = $self->_yaml;
    
    my ( %hosts, %groups );

    $yaml->[0]->{'hosts'}  = \%hosts;
    $yaml->[0]->{'groups'} = \%groups;

    $yaml->write($self->_config_file);

    return;
}

1;

