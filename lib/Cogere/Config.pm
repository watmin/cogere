package Cogere::Config;

use strict;
use warnings;

use Switch;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_ssh;
fieldhash my %_scp;
fieldhash my %_ssh_keygen;
fieldhash my %_hosts_dir;
fieldhash my %_hosts_conf;
fieldhash my %_default_user;
fieldhash my %_default_port;
fieldhash my %_key;
fieldhash my %_log_type;
fieldhash my %_log_dir;
fieldhash my %_log_file;
fieldhash my %_logstash;
fieldhash my %_log_host;
fieldhash my %_log_port;
fieldhash my %_log_proto;
fieldhash my %_log_app_name;

sub new {
    my ( $class, %args ) = @_;

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->_init(%args);

    return $self;
}

sub ssh {
    my ( $self, $ssh ) = @_;

    if ( !defined $_ssh{$self} and defined $ssh ) {
        $_ssh{$self} = $ssh;
    }
    elsif ( defined $_ssh{$self} and defined $ssh ) {
        carp "The ssh binary has already been defined.";
    }

    return $_ssh{$self};
}

sub scp {
    my ( $self, $scp ) = @_;

    if ( !defined $_scp{$self} and defined $scp ) {
        $_scp{$self} = $scp;
    }
    elsif ( defined $_scp{$self} and defined $scp ) {
        carp "The scp binary has already been defined.";
    }

    return $_scp{$self};
}

sub ssh_keygen {
    my ( $self, $ssh_keygen ) = @_;

    if ( !defined $_ssh_keygen{$self} and defined $ssh_keygen ) {
        $_ssh_keygen{$self} = $ssh_keygen;
    }
    elsif ( defined $_ssh_keygen{$self} and defined $ssh_keygen ) {
        carp "The ssh-keygen binary has already been defined.";
    }

    return $_ssh_keygen{$self};
}

sub hosts_dir {
    my ( $self, $hosts_dir ) = @_;

    if ( !defined $_hosts_dir{$self} and defined $hosts_dir ) {
        $_hosts_dir{$self} = $hosts_dir;
    }
    elsif ( defined $_hosts_dir{$self} and defined $hosts_dir ) {
        carp "The hosts directory has already been defined.";
    }

    return $_hosts_dir{$self};
}

sub hosts_conf {
    my ( $self, $hosts_conf ) = @_;

    if ( !defined $_hosts_conf{$self} and defined $hosts_conf ) {
        $_hosts_conf{$self} = $hosts_conf
    }
    elsif ( !defined $_hosts_conf{$self} and defined $hosts_conf ) {
        carp "The hosts configuration file has already been defined.";
    }

    return $_hosts_conf{$self};
}

sub hosts_conf_path {
    my ($self) = @_;

    my $hosts_conf_path = "${\$self->hosts_dir}/${\$self->hosts_conf}";

    return $hosts_conf_path;
}

sub default_user {
    my ( $self, $default_user ) = @_;

    if ( !defined $_default_user{$self} and defined $default_user ) {
        $_default_user{$self} = $default_user
    }
    elsif ( !defined $_default_user{$self} and defined $default_user ) {
        carp "The default user has already been defined.";
    }

    return $_default_user{$self};
}

sub default_port {
    my ( $self, $default_port ) = @_;

    if ( !defined $_default_port{$self} and defined $default_port ) {
        $_default_port{$self} = $default_port
    }
    elsif ( !defined $_default_port{$self} and defined $default_port ) {
        carp "The default port has already been defined.";
    }

    return $_default_port{$self};
}

sub key {
    my ( $self, $key ) = @_;

    if ( !defined $_key{$self} and defined $key ) {
        $_key{$self} = $key
    }
    elsif ( !defined $_key{$self} and defined $key ) {
        carp "The default key file has already been defined.";
    }

    return $_key{$self};
}

sub log_type {
    my ( $self, $log_type ) = @_;

    if ( !defined $_log_type{$self} and defined $log_type ) {
        $_log_type{$self} = $log_type
    }
    elsif ( !defined $_log_type{$self} and defined $log_type ) {
        carp "The log type has already been defined.";
    }

    return $_log_type{$self};
}

sub log_dir {
    my ( $self, $log_dir ) = @_;

    if ( !defined $_log_dir{$self} and defined $log_dir ) {
        $_log_dir{$self} = $log_dir
    }
    elsif ( !defined $_log_dir{$self} and defined $log_dir ) {
        carp "The log directory has already been defined.";
    }

    return $_log_dir{$self};
}

sub log_file {
    my ( $self, $log_file ) = @_;

    if ( !defined $_log_file{$self} and defined $log_file ) {
        $_log_file{$self} = $log_file
    }
    elsif ( !defined $_log_file{$self} and defined $log_file ) {
        carp "The log file has already been defined.";
    }

    return $_log_file{$self};
}

sub log_path {
    my ($self) = @_;

    my $log_path = "${\$self->log_dir}/${\$self->log_file}";

    return $log_path;
}

sub logstash {
    my ( $self, $logstash ) = @_;

    if ( !defined $_logstash{$self} and defined $logstash ) {
        $_logstash{$self} = $logstash
    }
    elsif ( !defined $_logstash{$self} and defined $logstash ) {
        carp "The logstash log type has already been set.";
    }

    return $_logstash{$self};
}

sub log_host {
    my ( $self, $log_host ) = @_;

    if ( !defined $_log_host{$self} and defined $log_host ) {
        $_log_host{$self} = $log_host
    }
    elsif ( !defined $_log_host{$self} and defined $log_host ) {
        carp "The logstash log host has already been defined.";
    }

    return $_log_host{$self};
}

sub log_port {
    my ( $self, $log_port ) = @_;

    if ( !defined $_log_port{$self} and defined $log_port ) {
        $_log_port{$self} = $log_port
    }
    elsif ( !defined $_log_port{$self} and defined $log_port ) {
        carp "The logstash log port has already been defined.";
    }

    return $_log_port{$self};
}

sub log_proto {
    my ( $self, $log_proto ) = @_;

    if ( !defined $_log_proto{$self} and defined $log_proto ) {
        $_log_proto{$self} = $log_proto
    }
    elsif ( !defined $_log_proto{$self} and defined $log_proto ) {
        carp "The logstash log protocol has already been defined.";
    }

    return $_log_proto{$self};
}

sub log_app_name {
    my ( $self, $log_app_name ) = @_;

    if ( !defined $_log_app_name{$self} and defined $log_app_name ) {
        $_log_app_name{$self} = $log_app_name
    }
    elsif ( !defined $_log_app_name{$self} and defined $log_app_name ) {
        carp "The logstash application name has already been defined.";
    }

    return $_log_app_name{$self};
}

sub _init {
    my ( $self, %args ) = @_;

    if ( defined $args{'config'} ) {
        $self->_parse_conf( $args{'config'} );
    }
    else {
        $self->_parse_args(%args);
    }

    $self->_check_vars;

    return;
}

sub _set_var {
    my ( $self, $var, $val ) = @_;

    switch ($var) {
        case /^ssh$/          { $self->ssh($val) }
        case /^scp$/          { $self->scp($val) }
        case /^ssh-keygen$/   { $self->ssh_keygen($val) }
        case /^ssh-keyscan$/  { $self->ssh_keyscan($val) }
        case /^hosts_dir$/    { $self->hosts_dir($val) }
        case /^hosts_conf$/   { $self->hosts_conf($val) }
        case /^default_user$/ { $self->default_user($val) }
        case /^default_port$/ { $self->default_port($val) }
        case /^key$/          { $self->key($val) }
        case /^log_type$/     { $self->log_type($val) }
        case /^log_dir$/      { $self->log_dir($val) }
        case /^log_file$/     { $self->log_file($val) }
        case /^log_host$/     { $self->log_host($val) }
        case /^log_port$/     { $self->log_port($val) }
        case /^log_proto$/    { $self->log_proto($val) }
        case /^log_app_name$/ { $self->log_app_name($val) }
        else                  { carp "The configuration paramater '$var' is not recognized" }
    }

    return;
}

sub _parse_conf {
    my ( $self, $config ) = @_;

    my $line;

    open my $config_h, '<', $config or croak "Failed to open '$config': $!";

    while ( $line = <$config_h> ) {
        chomp $line;
        next if $line =~ /^\s*#|^\s*$/;
        my ( $var, $val ) = split /=/, $line;
        $self->_set_var( $var, $val );
    }

    close $config_h;

    return;
}

sub _parse_args {
    my ( $self, %args ) = @_;

    for my $var ( keys %args ) {
        $self->_set_var( $var, $args{$var} );
    }

    return;
}

sub _check_vars {
    my ($self) = @_;

    $self->_check_cmd_vars;
    $self->_check_hosts_vars;
    $self->_check_default_vars;
    $self->_check_log_vars;
    return;
}

sub _check_cmd_vars {
    my ($self) = @_;

    $self->ssh or croak "The ssh command binary not defined.";
    croak "The ssh binary '${\$self->ssh}' not found." if !-x $self->ssh;

    $self->scp or croak "The scp command binary not defined.";
    croak "The scp binary '${\$self->scp}' not found." if !-x $self->scp;

    $self->ssh_keygen or croak "The ssh-keygen binary not defined.";
    croak "The binary ssh-keygen '${\$self->ssh_keygen}' not found." if !-x $self->ssh_keygen;

    return;
}

sub _check_hosts_vars {
    my ($self) = @_;

    $self->hosts_dir or croak "Hosts directory not defined.";
    croak "Hosts directory '${\$self->hosts_dir}' not found." if !-d $self->hosts_dir;

    $self->hosts_conf or croak "Hosts configuration not defined.";
    my $hosts_conf_path = "${\$self->hosts_dir}/${\$self->hosts_conf}";

    if ( !-f $hosts_conf_path ) {
        open my $handle, '>', $hosts_conf_path
          or croak "Failed to create empty hosts config '$hosts_conf_path': $!";
        close $handle;
    }
    croak "Hosts configuration '$hosts_conf_path' not found." if !-f $hosts_conf_path;

    return;
}

sub _check_default_vars {
    my ($self) = @_;

    $self->default_user or croak "Default user not defined.";
    $self->default_port or croak "Default port not defined.";
    $self->key          or croak "Default key not defined.";

    return;
}

sub _check_log_vars {
    my ($self) = @_;

    $self->log_type or croak "No logging type defined.";

    my @log_types = split /,/, $self->log_type;
    for my $log (@log_types) {
        switch ($log) {
            case /^file$/ {
                $self->log_dir  or croak "Log directory not defined.";
                $self->log_file or croak "Log file not defined.";

                my $log_path = "${\$self->log_dir}/${\$self->log_file}";
                if ( !-f $log_path ) {
                    open my $log_h, '>', $log_path
                      or croak "Failed to create log file '$log_path': $!";
                    close $log_h;
                }
                croak "Log file '$log_path' not found." if !-f $log_path;
            }
            case /^logstash$/ {
                $self->log_host     or croak "Logstash host is not defined.";
                $self->log_port     or croak "Logstash port is not defined.";
                $self->log_proto    or croak "Logstash protocol is not defined.";
                $self->log_app_name or croak "Logstash application name is not defined.";
                $self->logstash(1);
            }
            else { croak "Invalid loge type '$log'." }
        }
    }

    return;
}

1;

