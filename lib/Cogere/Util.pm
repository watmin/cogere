package Cogere::Util;

use strict;
use warnings;

use Logstash::Logger;

use Socket;
use POSIX qw/strftime/;
use JSON;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_cogere_config;

sub new {
    my ( $class, %args ) = @_;

    defined $args{'cogere-config'} or croak "Failed to provide Cogere::Config to Cogere::Util";

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->_cogere_config( $args{'cogere-config'} );

    return $self;
}

sub write_log {
    my ( $self, %log ) = @_;

    if ( $self->_cogere_config->log_file ) {
        my $log_file = $self->_cogere_config->log_path;
        my $timestamp = strftime "%Y-%m-%d %H:%M:%S", localtime;

        open my $handle, '>>', $log_file
          or croak "Failed to open '$log_file': $!.\n";

        printf $handle "%s\n", '#' x 80;
        printf $handle "Time:   %s\n", $timestamp;
        printf $handle "User:   %s\n", $log{'user'};
        printf $handle "Hosts:  %s\n", join( ', ', @{ $log{'hosts'} } );
        printf $handle "Reason: %s\n", $log{'reason'};
        print  $handle "Commands:\n";
        printf $handle "%s;\n", join( ";\n", @{ $log{'commands'} } );

        close $handle;
    }

    if ( $self->_cogere_config->logstash ) {
        my $json_o = JSON->new->utf8;

        $log{'message'} = $log{'reason'};
        delete $log{'reason'};

        my $logger = Logstash::Logger->new(
            'host'     => $self->_cogere_config->log_host,
            'port'     => $self->_cogere_config->log_port,
            'protocol' => $self->_cogere_config->log_proto,
            'app'      => $self->_cogere_config->log_app_name,
        );
        $logger->write( $json_o->encode( \%log ) ); 
    }

    return;
}

sub resolve_hostname {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname";

    my @packed = gethostbyname($hostname)
      or carp "Failed to resolve '$hostname'" and return 0;

    my @addresses = map { inet_ntoa($_) } @packed[ 4 .. $#packed ];

    my $address = $addresses[0];
    if ( scalar @addresses > 1 ) {
        carp "Multiple IP addresses returned for '$hostname', using '$address'";
    }

    return $address;
}

sub remove_fingerprint {
    my ( $self, $ipaddr ) = @_;

    defined $ipaddr or croak "Failed to provide IP address.";

    my $cmd = $self->_cogere_config->ssh_keygen;
    
    my $check = `$cmd -F $ipaddr`;
    croak "Failed to lookup '$ipaddr' from known_hosts: $check" if ( $? != 0 );

    if ($check) {
        my $out = `$cmd -R $ipaddr 2>&1`;
        croak "Failed to remove fingerprint for '$ipaddr': $out" if ( $? != 0 );

        print "Removed fingerprint for '$ipaddr'\n";
    }

    return;
}

sub add_defaults {
    my ( $self, $hostname, $host ) = @_;

    if ( !$host->{'ipaddr'} ) {
        $host->{'ipaddr'} = $self->resolve_hostname($hostname);
    }

    if ( !$host->{'username'} ) {
        $host->{'username'} = $self->_cogere_config->default_user;
    }

    if ( !$host->{'port'} ) {
        $host->{'port'} = $self->_cogere_config->default_port;
    }

    return $host;
}

sub _cogere_config {
    my ( $self, $cogere_config ) = @_;

    if ( !defined $_cogere_config{$self} and defined $cogere_config ) { 
        $_cogere_config{$self} = $cogere_config;
    }   
    elsif ( defined $_cogere_config{$self} and defined $cogere_config ) { 
        carp "Cogere::Util's Cogere::Config already defined.";
    }   

    return $_cogere_config{$self};
}

1;

