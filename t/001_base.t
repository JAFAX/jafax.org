use strict;
use warnings;

use Test::More tests => 7;

open *STDERR, ">/dev/null";

use_ok 'Buyo';
use_ok 'Sys::Error';
use_ok 'File::IO';
use_ok 'Buyo::Constants';
use_ok 'Buyo::MkAccount';
use_ok 'Buyo::MkRole';
use_ok 'Buyo::Utils';
