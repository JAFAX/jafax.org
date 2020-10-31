use strict;
use warnings;

use Buyo;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

my $app = Buyo->to_app;
is( ref $app, 'CODE', 'Got app' );

open *STDERR, ">/dev/null";

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[GET /] successful' );
