package Buyo;

use strict;
use warnings;
use English qw(-no_match_vars);
use utf8;

use feature qw(
    say
);

use boolean qw(:all);
use Carp;
use Dancer2;
use JSON qw();
use Data::Dumper;

use Buyo::Constants;
use Buyo::Utils qw(err_log);

our $VERSION = $Buyo::Constants::version;
my $DEBUG = true;

set traces  => 1;

# Dancer2 configuration
my $appdir = config->{appdir};
#my %config = load_config($appdir);

say "Dancer2 configuration";
say Dumper config;

my @getters;
my @posters;
my $json_txt;
{
    local $INPUT_RECORD_SEPARATOR;
    open my $fh, '<', "$appdir/api.json" or
      croak "Unable to open api.json";
    $json_txt = <$fh>;
    close $fh;
}
my $json = JSON->new();
my $data = $json->decode($json_txt);
my %paths = %{$data->{'paths'}};
err_log('== DEBUGGING ==: Loading site endpoints from JSON:') if $DEBUG;
foreach my $path (keys %paths) {
    err_log("== DEBUGGING ==: FOUND KEY: $path") if $DEBUG;
    if (exists $paths{$path}->{'get'}) {
        push @getters, $path;
    }
    if (exists $paths{$path}->{'post'}) {
        push @posters, $path;
    }
}
#
#foreach my $path (@getters) {
#    err_log("== DEBUGGING ==: Registering GET action for path $path") if $DEBUG;
#    get "$path" => sub {
#        err_log("== DEBUGGING ==: Triggering GET action for path $path") if $DEBUG;
#        template "index";
#    };
#}
#
get '/' => sub {
    template "index";
};

1;
