use strict;
use warnings;

use Test::More tests => 1;

open *STDERR, ">/dev/null";

use_ok 'Buyo';
