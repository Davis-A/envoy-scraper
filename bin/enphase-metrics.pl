#!/usr/bin/env perl
use v5.30.0;
use warnings;
use strict;
use experimental qw(signatures);

use JSON;
use Prometheus::Tiny;
use HTTP::Tiny;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use Net::Async::HTTP::Server::PSGI;
use Getopt::Long::Descriptive;



my ($opt, $usage) = describe_options(
  'enphase-metrics %o',
  [ 'envoy=s',  "the enphase envoy ip", { required => 1  } ],
  [ 'ip=s',     "the ip to listen on - default localhost", { default => "127.0.0.1"  } ],
  [ 'port=s',   "the port to connect to -default 8080",   { default  => "8080" } ],
  [ 'help|h',     "print usage message and exit", { shortcircuit => 1 } ],
);
 
print($usage->text), exit if $opt->help;

my $envoy = $opt->envoy;
my $listen_ip = $opt->ip;
my $listen_port = $opt->port;

# setup prom object
my $prom = Prometheus::Tiny->new;
$prom->declare("power_production", type => 'counter');
$prom->declare("power_consumption", type => 'counter');

my $loop = IO::Async::Loop->new;

# setup scrape
my $timer = IO::Async::Timer::Periodic->new(
  interval       => 10,
  first_interval => 0,

  on_tick => sub {
    $prom->clear;
    fill_metrics($prom);
  },
);

$timer->start;
$loop->add($timer);

# setup http server
my $http = Net::Async::HTTP::Server::PSGI->new(app => $prom->psgi);
$loop->add($http);

$http->listen(
  addr => {
    family   => 'inet',
    socktype => 'stream',
    ip       => $listen_ip,
    port     => $listen_port,
  },
  on_listen_error => sub {
    my ($self, $message) = @_;
    die "E: couldn't listen on $listen_ip:$listen_port: $message\n";
  },
);

$loop->run;


sub fill_metrics($prom) {

  my $error = 0;
  my $production = 0;
  my $consumption = 0;

  my $response = HTTP::Tiny->new->get("http://$envoy/production.json?details=1");
  
  if ($response->{success}) {
    my $data = decode_json($response->{content});
    $production = $data->{production}[0]{wNow};
    $consumption = $data->{consumption}[0]{wNow};
  } else {
    $error = 1;
  }
  $prom->set("power_production", $production, { error => $error });
  $prom->set("power_consumption", $consumption, { error => $error });
}
