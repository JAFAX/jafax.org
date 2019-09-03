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

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer2::Swagger;

use Buyo::Constants;
use Buyo::Utils;

sub get_json {
    my ($config, $json_file) = @_;

    err_log("== DEBUGGING ==: APPDIR: $config->{'appdir'}") if $config->{'debug'};
    err_log("== DEBUGGING ==: JSON FILE: $json_file") if $config->{'debug'};

    my $json_txt;
    {
        local $INPUT_RECORD_SEPARATOR;
        open my $fh, '<', "$config->{'appdir'}/$json_file" or
          croak "Unable to open $json_file";
        $json_txt = <$fh>;
        close $fh;
    }

    return $json_txt;
}

sub register_get_routes {
    my ($config, @paths) = @_;

    my $sub = (caller(0))[3];
    err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

    foreach my $path (@paths) {
        err_log("== DEBUGGING ==: Registering GET action for path $path") if $config->{'debug'};
        get "$path" => sub {
            err_log("== DEBUGGING ==: Triggering GET action for path $path") if $config->{'debug'};
            template "index";
        };
    }

    return true;
}

my $VERSION = $Buyo::Constants::version;
my $DEBUG   = true;

set traces  => 1;

my %app_config = (
    'appdir' => config->{appdir},
    'debug'  => $DEBUG
);

my $swagger = Dancer2::Swagger->new($DEBUG);

my @getters;
my @posters;

my $json_txt = get_json(\%app_config, 'api.json');
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

register_get_routes(\%app_config, @getters);

true;
