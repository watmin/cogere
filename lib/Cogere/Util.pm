package Cogere::Util;

use strict;
use warnings;

use Logstash::Logger;

use Crypt::GeneratePassword qw/chars/;
use POSIX qw/strftime/;
use File::Copy qw/copy/;
use JSON;
use Socket;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_cogere_config;

my @char_set = ( 'A' .. 'Z', 'a' .. 'z', 0 .. 9 );

sub new {
    my ( $class, %args ) = @_;

    defined $args{'cogere-config'} or croak "Failed to provide Cogere::Config to Cogere::Util";

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->_cogere_config( $args{'cogere-config'} );

    return $self;
}

sub gen_key {
    my ( $self, $hostname ) = @_;

    my $keys_path = $self->_cogere_config->keys_path;
    my $key = "$keys_path/$hostname";

    if ( -e "$key" or -e "$key.pub" ) {
        croak "Keys already exist.";
    }

    my $password = $self->_gen_pass;
    my $remoteid = $self->_gen_pass;

    my $cmd = $self->_cogere_config->ssh_keygen;

    my $out = `$cmd -q -b 4096 -t rsa -P "$password" -C "$remoteid" -f "$key"`;
    croak "Failed to generate SSH keys for '$hostname': $out." if ( $? != 0 );

    $self->_chmod_keys($key);

    return ( $password, $remoteid );
}

sub del_key {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";
    
    my $hostname  = $args{'hostname'};
    my $keys_path = $self->_cogere_config->keys_path;
    my $key       = "$keys_path/$hostname";

    if ( $args{'backup'} ) {
        $key = "$key.$args{'backup'}";
    }

    if ( -f $key ) {
        unlink "$key" or croak "Failed to delete default private key: $!";
        print "Deleted '$key'\n";
    }

    if ( -f "$key.pub" ) {
        unlink "$key.pub" or croak "Failed to delete default public key: $!";
        print "Deleted '$key.pub'.\n";
    }

    return;
}

sub backup_key {
    my ( $self, $hostname ) = @_;

    my $timestamp = time;
    my $keys_path = $self->_cogere_config->keys_path;
    my $key = "$keys_path/$hostname";
    my $backup = "$key.$timestamp";

    rename "$key", "$backup" or croak "Failed to backup '$key': $!.";
    rename "$key.pub", "$backup.pub" or croak "Failed to backup '$key.pub': $!.";

    return $timestamp;
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

sub copy_default_key {
    my ( $self, $hostname ) = @_;

    my $keys_path = $self->_cogere_config->keys_path;
    my $default_key = $self->_cogere_config->default_key;
    my $key = "$keys_path/$hostname";
    my $def = "$keys_path/$default_key";

    copy "$def", "$key" or croak "Failed to copy default private key: $!";
    copy "$def.pub", "$key.pub" or croak "Failed to copy default public key: $!";

    $self->_chmod_keys($key);

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
    my ( $self, $hostname, $host ) = @_;

    defined $hostname or croak "Failed to provide hostname.";

    my $ipaddr = $host->{'ipaddr'} || $self->resolve_hostname($hostname);

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

sub verify_host_key {
    my ( $self, $hostname, $host ) = @_;

    my $ssh_keygen  = $self->_cogere_config->ssh_keygen;
    my $ssh_keyscan = $self->_cogere_config->ssh_keyscan;

    my $ipaddr = $host->{'ipaddr'} || $self->resolve_hostname($hostname);

    my @local_fingerprint = `$ssh_keygen -H -F $ipaddr`;
    if ( $? != 0 ) {
        carp "Failed to lookup local fingerprint for '$hostname ($ipaddr)'.";
        return 1;
    }

    if ( scalar @local_fingerprint > 2 ) {
        carp "Duplicate fingerprints found for '$hostname ($ipaddr)'.";
        return 1;
    }
    elsif ( !@local_fingerprint ) {
        carp "No fingerprint found for '$hostname ($ipaddr)'.";
        return 1;
    }

    my ( $local_type, $local_hash, $remote_type );

    my @_local_type = split /\s+/, $local_fingerprint[0];
    $local_type = lc $_local_type[$#_local_type];

    my @_local_hash = split /\s+/, $local_fingerprint[1];
    $local_hash = $_local_hash[$#_local_hash];

    my @remote_fingerprint = `$ssh_keyscan -t $local_type -H $ipaddr 2>/dev/null`;
    if ( $? != 0 ) {
        carp "Failed to lookup remote fingerprint for '$hostname ($ipaddr)'.";
        return 1;
    }

    if ( !@remote_fingerprint ) {
        carp "Failed to retireve remote fingerprint for '$hostname ($ipaddr)'.";
        return 1;
    }

    my @_remote_hash = split /\s+/, $remote_fingerprint[0];
    my $remote_hash = $_remote_hash[$#_remote_hash];

    if ( $local_hash ne $remote_hash ) {
        carp "Remote fingerprint changed on '$hostname ($ipaddr)'.";
        return 1;
    }

    return;
}

sub new_default_key {
    my ($self) = @_;

    my $keys_path   = $self->_cogere_config->keys_path;
    my $default_key = $self->_cogere_config->default_key;

    $self->del_key($default_key);

    my ( $password, $remoteid ) = $self->gen_key($default_key);

    return ( $password, $remoteid );
}

sub print_default_key {
    my ($self) = @_;

    my $keys_path   = $self->_cogere_config->keys_path;
    my $default_key = $self->_cogere_config->default_key;

    my $key = "$keys_path/$default_key";

    if ( !-f $key or !-f "$key.pub" ) {
        croak "No default key found.";
    }

    open my $key_h, '<', "$key.pub" or croak "Failed to open '$key.pub': $!";
    print while <$key_h>;
    close $key_h;

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

sub _gen_pass {
    my ($self) = @_;

    my $pass = chars( 32, 32, [@char_set] );

    return $pass;
}

sub _chmod_keys {
    my ( $self, $key_path ) = @_;

    chmod 0600, "$key_path", "$key_path.pub"
      or croak "Failed to correct permissions on '$key_path', '$key_path.pub': $!.";

    return;
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

