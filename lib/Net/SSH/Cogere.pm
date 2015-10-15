package Net::SSH::Cogere;

use strict;
use warnings;

use Net::SSH::Cogere::HostsManager;
use Net::SSH::Cogere::Util;
use Net::SSH::Cogere::HostsConfig;
use Net::SSH::Cogere::Config;

use Net::OpenSSH;
use Parallel::ForkManager;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_config;
fieldhash my %_fork;
fieldhash my %_commands;
fieldhash my %_commands_file;
fieldhash my %_hosts;
fieldhash my %_groups;
fieldhash my %_hosts_config;
fieldhash my %_hosts_manager;
fieldhash my %_util;
fieldhash my %_user;
fieldhash my %_reason;
fieldhash my %_scp_mkdir;
fieldhash my %_scp_source;
fieldhash my %_scp_target;
fieldhash my %_scp_only;
fieldhash my %_all_hosts;

sub new {
    my ( $class, %args ) = @_;

    defined $args{'user'} or croak "Failed to provide user to Net::SSH::Cogere.";

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->user( $args{'user'} );
    delete $args{'user'};

    my $config = Net::SSH::Cogere::Config->new(%args);
    $self->config($config);

    my %hosts_config_args = (
        'hosts-config'  => $self->config->hosts_conf_path,
        'cogere-config' => $self->config,
    );
    my $hosts_config = Net::SSH::Cogere::HostsConfig->new(%hosts_config_args);
    $self->hosts_config($hosts_config);

    my %hosts_manager_args = (
        'hosts-config' => $self->hosts_config,
    );
    my $hosts_manager = Net::SSH::Cogere::HostsManager->new(%hosts_manager_args);
    $self->hosts_manager($hosts_manager);

    my %util_args = (
        'cogere-config' => $self->config,
    );
    my $util = Net::SSH::Cogere::Util->new(%util_args);
    $self->util($util);

    return $self;
}

sub list_hosts {
    my ($self) = @_;

    $self->hosts_manager->list_hosts;

    return;
}

sub list_groups {
    my ($self) = @_;

    $self->hosts_manager->list_groups;

    return;
}

sub list_members {
    my ( $self, $group ) = @_;

    defined $group or croak "Failed to provide group.";

    $self->hosts_manager->list_members($group);

    return;
}

sub new_host {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";
    $self->hosts_config->get_host( $args{'hostname'} )
      and croak "Hostname '$args{'hostname'} already defined.";

    if ( defined $args{'groups'} ) {
        $self->hosts_config->validate_groups( @{ $args{'groups'} } );
    }

    $self->hosts_config->new_host(%args);

    printf "Successfully added '%s'.\n", $args{'hostname'};

    if ( $args{'groups'} ) {
        $self->hosts_config->join_group(
            'hosts'  => [ $args{'hostname'} ],
            'groups' => $args{'groups'},
        );
    }

    return;
}

sub del_host {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname.";

    $self->hosts_config->del_host( 'hostname' => $hostname );

    print "Sucessfully deleted '$hostname'.\n";

    return;
}

sub cleanup_host {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname.";

    my $host = $self->hosts_config->get_host($hostname);

    if ($host) {
        $self->hosts_config->del_host( 'hostname' => $hostname );
    }

    return;
}

sub update {
    my ( $self, %args ) = @_;

    $self->hosts_config->update(%args);

    return;
}

sub remove_fingerprint {
    my ( $self, $ipaddr ) = @_;

    $self->util->remove_fingerprint($ipaddr);

    return;
}

sub new_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->new_group(%args);

    return;
}

sub del_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->del_group(%args);

    return;
}

sub join_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->join_group(%args);

    return;
}

sub leave_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->leave_group(%args);

    return;
}

sub commands {
    my ( $self, @commands ) = @_;

    if (@commands) {
        $_commands{$self} = [ @commands ];
    }

    return $_commands{$self};
}

sub commands_file {
    my ( $self, $commands_file ) = @_;

    if ( !defined $_commands_file{$self} and defined $commands_file ) {
        if ( !-f $commands_file ) {
            croak "Commands file not found.";
        }
        else {
            $_commands_file{$self} = $commands_file;
            open my $command_h, '<', $self->commands_file
              or croak "Failed to open commands file '${\$self->commands_file}: $!";

            my ( $command, @read_commands );
            while ( $command = <$command_h> ) {
                chomp $command;
                push @read_commands, $command;
            }

            close $command_h;

            $self->commands(@read_commands);
        }
    }

    return $_commands_file{$self};
}

sub all_hosts {
    my ( $self, $all_hosts ) = @_;

    if ( defined $all_hosts ) {
        $_all_hosts{$self} = $all_hosts;
    }

    return $_all_hosts{$self};
}

sub hosts {
    my ( $self, @hosts ) = @_;

    if (@hosts) {
        $_hosts{$self} = [ @hosts ];
    }

    return $_hosts{$self};
}

sub groups {
    my ( $self, @groups ) = @_;

    if (@groups) {
        $_groups{$self} = [ @groups ];
    }

    return $_groups{$self};
}

sub targets {
    my ($self) = @_;

    my %targets = (
        'hosts'  => $self->hosts,
        'groups' => $self->groups,
        'all'    => $self->all_hosts,
    );

    my @target_hosts = $self->hosts_manager->get_hosts(%targets);

    return [ @target_hosts ];
}

sub reason {
    my ( $self, $reason ) = @_;

    if ( defined $reason ) {
        $_reason{$self} = $reason;
    }

    return $_reason{$self};
}

sub fork {
    my ( $self, $fork ) = @_;

    if ( defined $fork ) {
        if ( $fork =~ /^(a|all)$/i ) {
            my @hosts = $self->hosts_config->get_all_hosts;
            $_fork{$self} = $#hosts + 1;
        }
        elsif ( $fork !~ /^\d+$/ ) {
            croak "Fork argument '$fork' is invalid.";
        }
        else {
            $_fork{$self} = $fork;
        }
    }

    return $_fork{$self};
}

sub scp_source {
    my ( $self, $scp_source ) = @_;

    if ( !defined $_scp_source{$self} and defined $scp_source ) {
        $_scp_source{$self} = $scp_source;
    }
    elsif ( defined $_scp_source{$self} and defined $scp_source ) {
        carp "Net::SSH::Cogere scp source already defined.";
    }

    return $_scp_source{$self};
}

sub scp_target {
    my ( $self, $scp_target ) = @_;

    if ( !defined $_scp_target{$self} and defined $scp_target ) {
        $_scp_target{$self} = $scp_target;
    }
    elsif ( defined $_scp_target{$self} and defined $scp_target ) {
        carp "Net::SSH::Cogere scp target already defined.";
    }

    return $_scp_target{$self};
}

sub scp_mkdir {
    my ( $self, $scp_mkdir ) = @_;

    if ( !defined $_scp_mkdir{$self} and defined $scp_mkdir ) {
        $_scp_mkdir{$self} = $scp_mkdir;
    }
    elsif ( defined $_scp_mkdir{$self} and defined $scp_mkdir ) {
        carp "Net::SSH::Cogere scp mkdir already defined.";
    }

    return $_scp_mkdir{$self};
}

sub scp_only {
    my ( $self, $scp_only ) = @_;

    if ( !defined $_scp_only{$self} and defined $scp_only ) {
        $_scp_only{$self} = $scp_only;
    }
    elsif ( defined $_scp_only{$self} and defined $scp_only ) {
        carp "Net::SSH::Cogere scp only already defined.";
    }

    return $_scp_only{$self};
}

sub connect {
    my ($self) = @_;

    defined $self->targets  or croak "No hosts defined.";
    defined $self->commands or croak "No commands defined.";
    defined $self->reason   or croak "No reason defined.";

    my %log = (
        'user'     => $self->user,
        'hosts'    => $self->targets,
        'commands' => $self->commands,
        'reason'   => $self->reason,
    );
    $self->util->write_log(%log);

    my $failure = $self->_run_commands;

    if ($failure) {
        return 1;
    }

    return;
}

sub user {
    my ( $self, $user ) = @_;

    if ( !defined $_user{$self} and defined $user ) {
        $_user{$self} = $user;
    }
    elsif ( defined $user and defined $user ) {
        carp "Net::SSH::Cogere user already defined.";
    }

    return $_user{$self};
}

sub config {
    my ( $self, $config ) = @_;

    if ( !defined $_config{$self} and defined $config ) {
        $_config{$self} = $config;
    }
    elsif ( defined $_config{$self} and defined $config ) {
        carp "Net::SSH::Cogere::Config already created.";
    }

    return $_config{$self};
}

sub hosts_config {
    my ( $self, $hosts_config ) = @_;

    if ( !defined $_hosts_config{$self} and $hosts_config ) {
        $_hosts_config{$self} = $hosts_config;
    }
    elsif ( defined $_hosts_config{$self} and defined $hosts_config ) {
        carp "Net::SSH::Cogere's Net::SSH::Cogere::HostsConfig already defined.";
    }

    return $_hosts_config{$self};
}

sub hosts_manager {
    my ( $self, $hosts_manager ) = @_;

    if ( !defined $_hosts_manager{$self} and defined $hosts_manager ) { 
        $_hosts_manager{$self} = $hosts_manager;
    }   
    elsif ( defined $_hosts_manager{$self} and defined $hosts_manager ) { 
        carp "Net::SSH::Cogere's Net::SSH::Cogere::HostsManager already defined.";
    }   

    return $_hosts_manager{$self};
}

sub util {
    my ( $self, $util ) = @_;

    if ( !defined $_util{$self} and defined $util ) {
        $_util{$self} = $util;
    }
    elsif ( defined $_util{$self} and defined $util ) {
        carp "Net::SSH::Cogere's Net::SSH::Cogere::Util already defined.";
    }

    return $_util{$self};
}

sub _open_ssh {
    my ( $self, $hostname, $host ) = @_;

    defined $hostname or croak "Failed to provide hostname.";
    defined $host     or croak "Failed to provide host.";

    open my $in_garb,  '<', '/dev/null';
    open my $out_garb, '>', '/dev/null';
    open my $err_garb, '>', '/dev/null';

    my $ssh = Net::OpenSSH->new(
        $host->{'ipaddr'},
        'user'              => $host->{'username'},
        'port'              => $host->{'port'},
        'key_path'          => $self->config->key,
        'default_stdout_fh' => $out_garb,
        'default_stderr_fh' => $err_garb,
        'default_stdin_fh'  => $in_garb,
        'ssh_cmd'           => $self->config->ssh,
        'scp_cmd'           => $self->config->scp,
        'master_opts'       => [
            -o => 'StrictHostKeyChecking=yes',
            -o => 'GSSAPIAuthentication=no',
            -o => 'PubkeyAuthentication=yes',
        ],
    );  

    if ( $ssh->error ) { 
        carp "Failed to SSH to '$hostname': ${\$ssh->error}.";
        return 1;
    }   

    return $ssh;
}

sub _execute_command {
    my ( $self, %args ) = @_;

    defined $args{'ssh'}      or croak "Failed to provide ssh object.";
    defined $args{'command'}  or croak "Failed to provide command.";
    defined $args{'hostname'} or croak "Failed to provide command.";

    my $ssh = $args{'ssh'};

    my ( $out, $pid ) = $ssh->pipe_out( $args{'command'} );

    if ( $ssh->error ) {
        warn "Failed to open command pipe on '$args{'hostname'}': ${\$ssh->error}.";
        return 1;
    }

    my $line;
    while ( $line = <$out> ) {
        if ( $self->fork ) {
            $line = "[$args{'hostname'}] $line";
        }
        print $line;
    }
    close $out;

    return;
}

sub _scp_put {
    my ( $self, %args ) = @_;

    defined $args{'ssh'}      or croak "Failed to provide ssh object.";
    defined $args{'hostname'} or croak "Failed to provide hostname.";

    if ( !-d $self->scp_source and !-f $self->scp_source ) {
        warn "Cannot scp '${\$self->scp_source}', source is neither a file nor a directory.";
        return 1;
    }

    my $ssh = $args{'ssh'};

    if ( $self->scp_mkdir ) {
        $self->_execute_command(
            'ssh'      => $ssh,
            'command'  => "mkdir -pv ${\$self->scp_target}",
            'hostname' => $args{'hostname'},
        );
    }

    $ssh->scp_put( { 'recursive' => 1 }, $self->scp_source, $self->scp_target );

    if ( $ssh->error ) {
        carp "Failed to scp source '${\$self->scp_source}': ${\$ssh->error}.";
        return 1;
    }

    return;
}

sub _run_commands {
    my ($self) = @_;

    my $failed;

    my $fork_num = $self->fork || 1;
    my $pm = Parallel::ForkManager->new($fork_num);

    $pm->run_on_finish(
        sub {
            my ( $pid, $exit_code, $ident ) = @_;

            if ( $exit_code == 1 ) {
                $failed = 1;
            }

            return;
        }
    );

  HOSTS:
    for my $hostname ( @{ $self->targets } ) {
        $pm->start($hostname) and next HOSTS;

        my $failure = $self->_connect_to_host($hostname);
        
        $pm->finish($failure);
    }
    $pm->wait_all_children;

    return $failed;
}

sub _connect_to_host {
    my ( $self, $hostname ) = @_;

    my $host = $self->hosts_config->get_host($hostname);
    $host = $self->util->add_defaults( $hostname, $host );
    my $source = $self->scp_source;
    my $target = $self->scp_target;

    my $ssh = $self->_open_ssh( $hostname, $host );
    return 1 if $ssh == 1;

    if ( $source and $target ) {
        my $failure = $self->_scp_put(
            'hostname' => $hostname,
            'ssh'      => $ssh,
        );

        if ( $failure ) {
            carp "Failed to copy source to '$hostname'.";
            return 1;
        }

        if ( $self->scp_only ) {
            print "Successfully copied '$source' to '$target' on '$hostname'.\n";
            return;
        }
    }

    for my $command ( @{ $self->commands } ) {
        my $failure = $self->_execute_command(
            'ssh'      => $ssh,
            'command'  => $command,
            'hostname' => $hostname,
        );

        if ( $failure ) {
            carp "Failed to execute command on '$hostname'.";
            return 1;
        }
    }

    return;
}

1;

