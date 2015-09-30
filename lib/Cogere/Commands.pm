package Cogere::Commands;

use Carp;

sub add_remote_key {
    my (%args) = @_;

    defined $args{'hostname'}   or croak "Failed to provide hostname.";
    defined $args{'host'}       or croak "Failed to provide host object.";
    defined $args{'public-key'} or croak "Failed to provide public key path.";

    my $hostname = $args{'hostname'};
    my $host     = $args{'host'};
    my $username = $host->{'username'};

    my ( $key, $key_h );
    open my $key_h, '<', $args{'public-key'}
      or croak "Failed to open '$args{'public-key'}': $!";
    chomp ( $key = <$key_h> );
    close $key_h;

    my %command_set = (
        'commands' => [ "echo '$key' >> /home/$username/.ssh/authorized_keys" ],
        'reason'   => "Adding SSH key to '$hostname'",
        'hosts'    => [ $hostname ],
    );

    return %command_set;
}

sub del_remote_key {
    my (%args) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";
    defined $args{'host'}     or croak "Failed to provide host object.";

    my $hostname = $args{'hostname'};
    my $host     = $args{'host'};
    my $username = $host->{'username'};

    my $remoteid = defined $args{'remoteid'} ? $args{'remoteid'} : $host->{'remoteid'};

    my %command_set = (
        'commands' => [ "sed -i '/$remoteid\$/d' /home/$username/.ssh/authorized_keys" ],
        'reason'   => "Removing SSH key from '$hostname'",
        'hosts'    => [ $hostname ],
    );

    return %command_set;
}

1;

