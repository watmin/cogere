package Cogere::HostsManager;

use strict;
use warnings;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_hosts_config;

sub new {
    my ( $class, %args ) = @_;

    defined $args{'hosts-config'} or croak "Failed to provide Cogere::HostsConfig to Cogere::HostsManager.";

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->_hosts_config( $args{'hosts-config'} );

    return $self;
}

sub get_hosts {
    my ( $self, %targets ) = @_;

    if ( !defined $targets{'hosts'} and !defined $targets{'groups'} and !defined $targets{'all'} ) {
        croak "No hosts or groups provided.";
    }

    if ( $targets{'all'} ) {
        my @all_hosts = $self->_hosts_config->get_all_hosts;
        my @hosts;
        if ( $targets{'hosts'} ) {
            @hosts = @{ $targets{'hosts'} };
        }
        my @merged = ( @all_hosts, @hosts );
        $targets{'hosts'} = [ @merged ];
    }

    my ( $hosts, $negate_hosts )   = $self->_process_hosts( $targets{'hosts'} );
    my ( $groups, $negate_groups ) = $self->_process_groups( $targets{'groups'} );
    my @target_hosts = $self->_process_negate(
        'hosts'         => $hosts,
        'negate_hosts'  => $negate_hosts,
        'groups'        => $groups,
        'negate_groups' => $negate_groups,
    );

    @target_hosts = $self->clean_targets(@target_hosts);

    return @target_hosts;
}

sub list_hosts {
    my ($self) = @_;

    my @config_hosts = $self->_hosts_config->get_all_hosts;
    @config_hosts = $self->clean_targets(@config_hosts);

    for my $host (@config_hosts) {
        printf "%s\n", $host;
    }

    return;
}

sub list_groups {
    my ($self) = @_;

    my @config_groups = $self->_hosts_config->get_all_groups;
    @config_groups = $self->clean_targets(@config_groups);

    for my $group (@config_groups) {
        $self->list_members($group);
    }

    return;
}

sub list_members {
    my ( $self, @groups ) = @_;

    for my $group (@groups) {
        my @members = $self->_hosts_config->get_members($group);
        printf "%s - %s\n", $group, join ',', @members;
    }

    return;
}

sub clean_targets {
    my ( $self, @targets ) = @_;

    @targets = $self->_hosts_config->dedup(@targets);

    return @targets;
}

sub _hosts_config {
    my ( $self, $hosts_config ) = @_;

    if ( !defined $_hosts_config{$self} and defined $hosts_config ) {
        $_hosts_config{$self} = $hosts_config;
    }
    elsif ( defined $_hosts_config{$self} and defined $hosts_config ) {
        carp "Cogere::HostManager's Cogere::HostsConfig already defined.";
    }

    return $_hosts_config{$self};
}

sub _process_hosts {
    my ( $self, $hosts_ref ) = @_;

    defined $hosts_ref or return;

    my @dirty_hosts = @{ $hosts_ref };
    my @clean_hosts = $self->_hosts_config->dedup(@dirty_hosts);
    my ( @hosts, @negate_hosts );

    for my $host (@clean_hosts) {
        if ( $host =~ /^:/ ) {
            ( my $negate_host = $host ) =~ s/^://;
            $self->_hosts_config->validate_hosts($negate_host);
            push @negate_hosts, $negate_host;
        }
        else {
            $self->_hosts_config->validate_hosts($host);
            push @hosts, $host;
        }
    }

    return ( [ @hosts ], [ @negate_hosts ] );
}

sub _process_groups {
    my ( $self, $groups_ref ) = @_;

    defined $groups_ref or return;

    my @dirty_groups = @{ $groups_ref };
    my @clean_groups = $self->_hosts_config->dedup(@dirty_groups);
    my ( @groups, @negate_groups );

    for my $group (@clean_groups) {
        if ( $group =~ /^:/ ) {
            ( my $negate_group = $group ) =~ s/^://;
            $self->_hosts_config->validate_groups($negate_group);
            push @negate_groups, $negate_group;
        }
        else {
            $self->_hosts_config->validate_groups($group);
            push @groups, $group;
        }
    }

    return ( [ @groups ], [ @negate_groups ] );
}

sub _process_negate {
    my ( $self, %targets ) = @_;

    my ( @hosts, @negate_hosts, @groups, @negate_groups );

    if ( $targets{'hosts'} ) {
        @hosts = @{ $targets{'hosts'} };
    }

    if ( $targets{'negate_hosts'} ) {
        @negate_hosts = @{ $targets{'negate_hosts'} };
    }

    if ( $targets{'groups'} ) {
        @groups = @{ $targets{'groups'} };
    }

    if ( $targets{'negate_groups'} ) {
        @negate_groups = @{ $targets{'negate_groups'} };
    }

    my @target_hosts  = ( @hosts );

    for my $group (@groups) {
        my @members = $self->_hosts_config->get_members($group);
        push @target_hosts, @members;
    }

    for my $group (@negate_groups) {
        my @members = $self->_hosts_config->get_members($group);
        for my $member (@members) {
            @target_hosts = grep { $_ ne $member } @target_hosts;
        }
    }

    for my $host (@negate_hosts) {
        @target_hosts = grep { $_ ne $host } @target_hosts;
    }

    return @target_hosts;
}

1;

