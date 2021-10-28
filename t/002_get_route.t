use strict;
use warnings;

use Buyo;
use Test::More tests => 32;
use Plack::Test;
use HTTP::Request::Common;

my $app = Buyo->to_app;
is( ref $app, 'CODE', 'Got app' );

open *STDOUT, ">/dev/null";
open *STDERR, ">/dev/null";

$ENV{'DEBUG'} = 0;

my $test = Plack::Test->create($app);
my $res = undef;
foreach my $route ('/', '/about', '/carousel', '/registration/attendee',
                    '/registration/artists', '/registration/maid_cafe',
                    '/registration/vendors', '/registration/volunteers',
                    '/events/artists', '/events/cosplay', '/events/culture',
                    '/events/gaming', '/events/maid_cafe',
                    '/events/media', '/events/media/amv_contest',
                    '/events/media/anime', '/events/media/manga',
                    '/events/music', '/events/panels', '/events/schedule',
                    '/events/vendors', '/guests', '/location/hotel',
                    '/location/venue', '/news', '/policies/rules',
                    '/policies/privacy', '/policies/inclusion',
                    '/policies/bylaws', '/policies/volunteer_guidelines',
                    '/contact') {
    $res  = $test->request( GET $route );
    ok( $res->is_success, "[GET $route] successful" );
}

