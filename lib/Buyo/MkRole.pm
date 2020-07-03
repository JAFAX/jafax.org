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
    use Term::ANSIColor;
    use Throw qw(throw classify);
    use Try::Tiny qw(try catch);

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Sys::Error;

    sub new ($class) {
        my $self = {};

        bless($self, $class);
        return $self;
    }

    our sub show_help ($self) {
        say "mkrole: A tool to create roles for the Buyo web application";
        say "=" x 39;
        say "\nOptions:";
        say "-" x 8;
        say "  -n|--name ROLE_NAME    A name for the role";
        say "  -d|--description TEXT  A description for the role";
        say "  -i|--id INTEGER        A numeric ID for the role";
        say "  -v|--version           Display the version of this tool";
        say "  -h|--help              Display this help text";
    }

    our sub show_version ($self) {
        say "mkrole: A tool to create roles for the Buyo web application";
        say "=" x 59;
        say "Author:  Gary Greene <webmaster at jafax dot org>";
        say "License: Apache Public License, version 2";
        say "         See https://www.apache.org/licenses/LICENSE-2.0 for";
        say "         the full text of the license";
        say "Version: 0.0.1";
    }

    our sub verify_options ($self, $role_name, $description) {
        if (! defined $role_name) {
            say "ERROR: Missing role name!";
            exit 1;
        }
        if (! defined $description) {
            say "ERROR: Missing role description!";
            exit 1;
        }
    }

    our sub get_application_prefix ($self) {
        my $prefix = "$FindBin::Bin/..";
        return $prefix;
    }

    our sub next_available_id ($self) {
        my $role_id = undef;

        my $prefix = $self->get_application_prefix();
        if (-f "$prefix/conf.d/roles.lst") {
            # first, open role list
            my $fh = undef;
            my $fc = undef;
            my $status = undef;

            my $fio = File::IO->new();
            ($fh, $status) = $fio->open('r', "$prefix/conf.d/roles.lst");
            ($fc, $status) = $fio->read($fh, -s $fh);
            $status = $fio->close($fh);

            my @content = split(/\n/, $fc);

            # now that we have the file contents, get the last entry's role id number
            my $last_record = $content[-1];
            my (undef, $last_id, undef, undef) = split(':', $last_record);
            $role_id = $last_id++;
        } else {
            # there is no roles.lst, so assume this is the first run of this tool, seed it
            $role_id = 0;
        }

        return $role_id;
    }

    our sub create_role ($self, $id, $name, $description) {
        my $prefix = $self->get_application_prefix();

        my $fh = undef;
        my $status = undef;
        my $fio = File::IO->new();
        ($fh, $status) = $fio->open('a', "$prefix/conf.d/roles.lst");
        say $fh "$name:$id:\"$description\"";
        $status = $fio->close($fh);
    }

    true;
}