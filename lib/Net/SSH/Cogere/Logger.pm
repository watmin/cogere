package Net::SSH::Cogere::Logger;

use Sys::Hostname;
use IO::Socket::INET;
use Time::Piece;
use JSON;
use Carp;

sub new {
    my ($class, %params) = @_; 

    # Defaults
    $params{host}     = '127.0.0.1' unless $params{host};
    $params{port}     = '12345'     unless $params{port};
    $params{protocol} = 'tcp'       unless $params{protocol};
    $params{app}      = 'logger'    unless $params{app};

    my $self = { 
      _host     => $params{host},
      _port     => $params{port},
      _protocol => $params{protocol},
      _app      => $params{app},
    };  

    return bless($self, $class);
}

sub write {
    my ($self, $input) = @_; 

    my $logstash = new IO::Socket::INET (
        PeerHost => $self->{_host},
        PeerPort => $self->{_port},
        Proto    => $self->{_protocol},
        Timeout  => 2,
    ) or croak "Logstash::Logger failed to connect: $@\n";

    my $json_o = JSON->new->utf8;
    $json_o->convert_blessed(1);

    my $json_d = $json_o->decode($input);

    my $time_o = localtime;
    $json_d->{timestamp} = sprintf '%s %s', $time_o->date, $time_o->time;
    $json_d->{hostname} = hostname;
    $json_d->{level} = '22';
    $json_d->{application} = $self->{_app}
      unless defined $json_d->{application};

    my $json = $json_o->encode($json_d);
    $logstash->send($json);
    $logstash->close;

    return 1;
}

1;

