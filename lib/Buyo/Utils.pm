#!/usr/bin/env perl
#
# Author: Gary Greene <greeneg@tolharadys.net>
# Copyright: 2019 JAFAX, Inc. All Rights Reserved
#
##########################################################################
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Buyo::Utils v1.2.21 {
    use strictures;
    use English qw(-no_match_vars);
    use utf8;

    use feature ":5.26";
    use feature 'lexical_subs';
    use feature 'signatures';
    no warnings "experimental::signatures";

    use boolean qw(:all);
    use base qw(Exporter);
    use Carp;
    use Data::Dumper;

    BEGIN {
        use Exporter;
        our (@EXPORT, @EXPORT_OK);

        # set the version for version checking
        @EXPORT      = qw(
            err_log
        );
        @EXPORT_OK   = qw();
    }

    our sub err_log (@msg) {
        return print {*STDERR} "@msg\n";
    }

    END { }       # module clean-up code here (global destructor)

    true;  # don't forget to return a true value from the file
}
