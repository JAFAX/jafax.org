#!/usr/bin/env perl
#
# Author: Gary Greene <greeneg@tolharadys.net>
# Copyright: 2019-2022 JAFAX, Inc. All Rights Reserved
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

package Buyo::MkRole {
    use strictures;
    use utf8;
    use English;

    use feature ":5.26";
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";
    use feature "lexical_subs";
    use feature "signatures";
    use feature "switch";

    use boolean;
    use Data::Dumper;
    use Types::Standard -all;
    use Return::Type;
    use Term::ANSIColor;
    use Throw qw(throw classify);
    use Try::Tiny qw(try catch);
    use Type::Library -base;
    use Type::Utils;

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use File::IO;
    use Sys::Error;
    use Value::TypeCheck;

    use Buyo::Constants;
    use Buyo::Utils;

    my $debug  = undef;
    my $logger = undef;
    my $loglvl = undef;
    my $fio    = undef;
    my $err    = undef;
    my $utils  = undef;

    my $VERSION = $Buyo::Constants::VERSION;

    sub new :ReturnType(Object) ($class, $flags) {
        type_check($class, Str);
        type_check($flags, HashRef);

        my $self = {};

        $debug  = $flags->{'debug'};
        $logger = $flags->{'logger'};
        $loglvl = $flags->{'loglevel'};
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        if ($debug eq true) {
            say STDERR "== DEBUGGING ==: Debugging enabled";
            say STDERR "== DEBUGGING ==: Standard flags:";
            say STDERR "== DEBUGGING ==:    logger    : $logger";
            say STDERR "== DEBUGGING ==:    log level : $loglvl";
        }

        $err    = Sys::Error->new();
        $fio    = File::IO->new();

        $utils  = Buyo::Utils->new($debug);

        bless($self, $class);
        return $self;
    }

    our sub get_rolelist ($self, $file) {
        type_check($self, Object);
        type_check($file, Str);

        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        say STDERR "== DEBUGGING ==: File: $file" if $debug eq true;

        my @content;
        if (-f $file) {
            say STDERR "== DEBUGGING ==: File '$file' exists" if $debug eq true;
            # first, open role list
            my $fh = undef;
            my $fc = undef;
            my $status = undef;
            try {
                # File::IO already throws on error, just need to catch it
                say STDERR "== DEBUGGING ==: Attempting to open $file" if $debug eq true;
                ($fh, $status) = $fio->open('r', $file);
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };
            try {
                say STDERR "== DEBUGGING ==: Attempting to read file handle" if $debug eq true;
                ($fc, $status) = $fio->read($fh, -s $fh); 
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };
            try {
                say STDERR "== DEBUGGING ==: Attempting to close file handle" if $debug eq true;
                $status = $fio->close($fh);
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };

            @content = split(/\n/, $fc);
        }

        return @content;
    }

    our sub check_id_exists ($self, $id) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;

        my $prefix = $utils->get_application_prefix();
        my @content = $self->get_rolelist("$prefix/conf.d/roles.lst");
        if (@content) {
            # now that we have the file contents, check for duplicate ids
            # format for account.lst:
            #
            # colon delimited
            #
            # fields:
            # 0: role name
            # 1: UID (numeric user id)
            # 2: description
            foreach my $record (@content) {
                my (undef, $rid, undef) = split(':', $record);
                say STDERR "== DEBUGGING ==: Requested ID: $id" if $debug eq true;
                say STDERR "== DEBUGGING ==: Record ID:    $rid" if $debug eq true;
                if ($id eq $rid) {
                    my $trace = $err->get_trace(caller(0));
                    return false, {
                        'error'         => "Role ID not unique",
                        'type'          => 137,
                        'error_string'  => "Role ID is not unique",
                        'info'          => "Cannot create requested role with ID '$id'",
                        'trace'         => $trace
                    };
                }
            }
        }

        return true, {
            'type' => 'OK',
            'code' => 0,
            'msg'  => 'Successful operation'
        };
    }

    our sub check_role_exists ($self, $role_name) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;

        my $prefix = $utils->get_application_prefix();
        my @content = $self->get_rolelist("$prefix/conf.d/roles.lst");
        
        if (@content) {
            # now that we have the file contents, get the last entry's role id number
            # format for account.lst:
            #
            # colon delimited
            #
            # fields:
            # 0: role name
            # 1: UID (numeric user id)
            # 2: description
            foreach my $record (@content) {
                my ($role, undef, undef) = split(':', $record);
                if ($role eq $role_name) {
                    my $trace = $err->get_trace(caller(0));
                    return false, {
                        'error'         => "Role name not unique",
                        'type'          => 142,
                        'error_string'  => "Role name is not unique",
                        'info'          => "Cannot create requested role '$role_name'",
                        'trace'         => $trace
                    };
                }
            }
        }

        return true, {
            'type' => 'OK',
            'code' => 0,
            'msg'  => 'Successful operation'
        };
    }

    our sub verify_options ($self, $role_name, $description) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        if (! defined $role_name) {
            say STDERR "ERROR: Missing role name!";
            exit 1;
        } else {
            # check that the role name does not already exist
            my ($response, $status) = $self->check_role_exists($role_name);
            if ($response ne true) {
                $err->err_msg($status, __PACKAGE__);
            }
        }
        if (! defined $description) {
            say "ERROR: Missing role description!";
            exit 1;
        }
    }

    our sub next_available_id ($self) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        my $role_id = undef;

        my $prefix = $utils->get_application_prefix();
        my @content = get_rolelist("$prefix/conf.d/roles.lst");
        if (@content) {
            # now that we have the file contents, get the last entry's role id number
            my $last_record = $content[-1];
            my (undef, $last_id, undef) = split(':', $last_record);
            $role_id = $last_id++;
        } else {
            # there is no roles.lst, so assume this is the first run of this tool, seed it
            $role_id = 0;
        }

        return $role_id;
    }

    our sub get_role_id ($self, $role_name) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;

        my $prefix = $utils->get_application_prefix();
        my @content = get_rolelist("$prefix/conf.d/roles.lst");
        if (@content) {
            # walk the list and if $role_name matches $record_role_name, return
            # $record_role_id
            foreach my $record (@content) {
                my ($record_role_name, $record_role_id, undef) = split(/\:/, $record);
                if ($role_name eq $record_role_name) {
                    return $record_role_id;
                } else {
                    return undef;
                }
            }
        }
    }

    our sub get_role_name ($self, $role_id) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;

        my $prefix = $utils->get_application_prefix();
        my @content = get_rolelist("$prefix/conf.d/roles.lst");
        if (@content) {
            # walk the list and if $role_name matches $record_role_name, return
            # $record_role_id
            foreach my $record (@content) {
                my ($record_role_name, $record_role_id, undef) = split(/\:/, $record);
                if ($role_id eq $record_role_id) {
                    return $record_role_name;
                } else {
                    return undef;
                }
            }
        }
    }

    our sub create_role ($self, $flags) {
        say STDERR "== DEBUGGING ==: Sub ". (caller(0))[3] if $debug eq true;
        my $prefix = $utils->get_application_prefix();

        my $description = $flags->{'description'};
        my $id          = $flags->{'id'};
        my $name        = $flags->{'role_name'};

        my $fh = undef;
        my $response = undef;
        my $status = undef;
        try {
            ($fh, $status) = $fio->open('a', "$prefix/conf.d/roles.lst");
        } catch {
            $err->err_msg($status, __PACKAGE__);
        };
        try {
            ($response, $status) = $self->check_id_exists($id);
            if ($response ne true) {
                throw $status->{'error'}, $status;
            }
        } catch {
            $err->err_msg($status, __PACKAGE__);
        };
        say $fh "$name:$id:\"$description\"";
        try {
            $status = $fio->close($fh);
        } catch {
            $err->err_msg($status, __PACKAGE__);
        };
    }

    our sub show_help {
        say "mkrole: A tool to create roles for the Buyo web application";
        say "=" x 59;
        say "\nOptions:";
        say "-" x 8;
        say "  -n|--name ROLE_NAME    A name for the role";
        say "  -d|--description TEXT  A description for the role";
        say "  -i|--id INTEGER        A numeric ID for the role";
        say "  -v|--version           Display the version of this tool";
        say "  -h|--help              Display this help text";
    }

    our sub show_version {
        say "mkrole: A tool to create roles for the Buyo web application";
        say "=" x 59;
        say "\nVersion: 0.0.1";
        say "Author:  Gary Greene <webmaster at jafax dot org>";
        say "License: Apache Public License, version 2";
        say "         See https://www.apache.org/licenses/LICENSE-2.0 for";
        say "         the full text of the license";
    }

    true;
}
