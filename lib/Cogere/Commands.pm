package Cogere::Commands;

use Carp;

sub add_remote_key {
    my (%args) = @_;

    defined $args{'hostname'}   or croak "Failed to provide hostname.";
    defined $args{'public-key'} or croak "Failed to provide public key path.";

    my $hostname = $args{'hostname'};

    my ( $key, $key_h );
    open my $key_h, '<', $args{'public-key'}
      or croak "Failed to open '$args{'public-key'}': $!";
    chomp ( $key = <$key_h> );
    close $key_h;

    my %command_set = (
        'commands' => [ "echo '$key' >> ~/.ssh/authorized_keys" ],
        'reason'   => "Adding SSH key to '$hostname'",
        'hosts'    => [ $hostname ],
    );

    return %command_set;
}

sub del_remote_key {
    my (%args) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";

    my $hostname = $args{'hostname'};

    my $remoteid = defined $args{'remoteid'} ? $args{'remoteid'} : $host->{'remoteid'};

    my %command_set = (
        'commands' => [ "sed -i '/$remoteid\$/d' ~/.ssh/authorized_keys" ],
        'reason'   => "Removing SSH key from '$hostname'",
        'hosts'    => [ $hostname ],
    );

    return %command_set;
}

sub copy_key {
    my (%args) = @_;

    defined $args{'hostname'}   or croak "Failed to provide hostname.";
    defined $args{'public-key'} or croak "Failed to provide public key path.";

    my $hostname = $args{'hostname'};

    my ( $key, $key_h );
    open my $key_h, '<', $args{'public-key'}
      or croak "Failed to open '$args{'public-key'}': $!";
    chomp ( $key = <$key_h> );
    close $key_h;

    my @commands = (
        'umask 077',
        'test -d ~/.ssh || mkdir ~/.ssh',
        "echo '$key' >> ~/.ssh/authorized_keys",
        "test -x /sbin/restorecon && /sbin/restorecon ~/.ssh ~/.ssh/authorized_keys >/dev/null 2>&1",
    );

    my %command_set = (
        'commands' => [ @commands ],
        'reason'   => "Copying local SSH key to '$hostname'",
        'hosts'    => [ $hostname ],
    );

    return %command_set;
}

1;

