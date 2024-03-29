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

=pod

=encoding UTF-8

=head1 NAME

Buyo - Main class for the Buyo Application Framework

=head1 VERSION

Version 1.2.96

=head1 DESCRIPTION

This is the primary class used by the Buyo Application Framework run as a
Dancer2 web application.

=head1 AUTHOR

Gary L. Greene, Jr. <webmaster@jafax.org>

=head1 COPYRIGHT

Copyright (c) 2019-2023 JAFAX, Inc. All Rights Reserved

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.

=cut
package Buyo {
    use strictures;
    use English qw(-no_match_vars);
    use utf8;

    use boolean qw(:all);
    use CGI::Carp qw(carp croak fatalsToBrowser);
    use Config::IniFiles;
    use Dancer2;
    use Devel::Leak::Object qw|GLOBAL_bless|;
    use JSON qw();
    use Data::Dumper;
    use LWP::UserAgent;
    use MIME::Lite;
    use Return::Type;
    use Types::Standard -all;
    use Try::Tiny qw(try catch);
    use Throw qw(throw classify);
    use URI::Encode;

    use feature ":5.26";
    use feature 'lexical_subs';
    use feature 'signatures';
    use feature 'switch';
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Buyo::Constants;
    use Buyo::Logger;
    use Buyo::Utils;

    use Value::TypeCheck qw(type_check);
    use File::IO;

    # constants
    use constant MTIME_ATTR => 9;

    our $VERSION = $Buyo::Constants::VERSION;

    # this global is to avoid copying it everywhere
    our $config;

    my $err    = undef;
    my $fio    = undef;
    my $logger = undef;

    # Return type is Value, as hash doesn't have a value that is
    # codefied
    my sub load_config :ReturnType(list => HashRef) ($appdir) {
        type_check($appdir, Str);

        my $sub = (caller(0))[3];

        my $ini_file = "${appdir}/conf.d/config.ini";

        my $cfg = undef;
        try {
            $cfg = Config::IniFiles->new(-file => $ini_file, -allowcontinue => 1) or
                        throw "File IO error", {
                            'type'         => int($OS_ERROR),
                            'error_string' => $OS_ERROR,
                            'log_msg'      => "Could not read configuration: $OS_ERROR",
                            'info'         => "Attempted to open '$ini_file' for read"
            };
        } catch {
            classify $ARG, {
                2       => sub {
                    $logger->error_msg($ARG, "File not found");
                },
                13      => sub {
                    $logger->error_msg($ARG, "Access denied");
                },
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };
        try {
            if (! defined $cfg) {
                throw "INI parsing error", {
                    'type'         => 1001, # INI file format error
                    'error_string' => @Config::IniFiles::errors,
                    'log_msg'      => "Cannot parse INI file",
                    'info'         => "Attempted to parse '$ini_file'"
                };
            }
        } catch {
            classify $ARG, {
                1001 => sub {
                    $logger->error_msg($ARG, "Cannot parse");
                },
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };

        my %configuration = ();

        $configuration{'debug'}           = $cfg->val('General', 'debugging');
        $configuration{'trace'}           = $cfg->val('General', 'trace');
        $configuration{'webroot'}         = $cfg->val('Web', 'webpath');
        $configuration{'session_support'} = $cfg->val('Web', 'session_support', 0);
        $configuration{'article_mech'}    = $cfg->val('Web', 'article_mech', "JSON");
        $configuration{'etcd_user'}       = $cfg->val('etcd', 'user');
        $configuration{'etcd_password'}   = $cfg->val('etcd', 'pass');
        $configuration{'site_key'}        = $cfg->val('reCAPTCHA', 'site_key');
        $configuration{'service_key'}     = $cfg->val('reCAPTCHA', 'service_key');

        return %configuration;
    }

    my sub get_json :ReturnType(Str) ($json_file) {
        type_check($json_file, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        $logger->err_log("== DEBUGGING ==: APPDIR: $config->{'appdir'}") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: JSON FILE: $json_file") if $config->{'debug'};

        my $fh = undef;
        my $status = undef;
        my $json_txt = undef;
        my $file_full_path = "$config->{'appdir'}/$json_file";
        try {
            ($fh, $status) = $fio->open('r', $file_full_path);
        } catch {
            $err->err_msg($status, __PACKAGE__);
        };
        try {
            ($json_txt, $status) = $fio->read($fh, -s $fh);
        } catch {
            $err->err_msg($status, __PACKAGE__);
        };
        try {
            $status = $fio->close($fh);
        } catch {
            $err->err_msg($status, __PACKAGE__);
        };

        return $json_txt;
    }

    my sub get_mtime :ReturnType(Int) ($file_name) {
        type_check($file_name, Str);

        my $site_parent_path = "";
        given ($file_name) {
            when (/images/) {
                $site_parent_path = 'public';
            }
            default {
                $site_parent_path = '';
            }
        }

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $f_mtime = undef;
        $logger->err_log("== DEBUGGING ==: file: " . $file_name) if $config->{'debug'};
        my $fq_path = "" . $config->{'appdir'} . $site_parent_path . ${file_name};
        # strip excess '/' characters
        $fq_path =~ s/\/\//\//g;
        $logger->err_log("== DEBUGGING ==: Fully-qualified path: ". $fq_path) if $config->{'debug'};

        # get the file's mtime
        $f_mtime = (stat($fq_path))[MTIME_ATTR];
        $logger->err_log("== DEBUGGING ==: mtime: ". $f_mtime) if $config->{'debug'};

        return $f_mtime;
    }

    my sub get_article_from_json :ReturnType(list => Str) ($article, $type) {
        type_check($article, Str);
        type_check($type, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt;
        if ($type eq 'news') {
            $json_txt      = get_json("content/${article}.json");
        } elsif ($type eq 'bio') {
            $json_txt      = get_json("content/guests/${article}.json");
        }
        my $json           = JSON->new();
        my $article_struct = undef;
        try {
            $article_struct = $json->decode($json_txt) or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, '${article}.json'",
                    'info'         => "Attempted to decode JSON content from '${article}.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };

        if ($type eq 'news') {
            $logger->err_log("== DEBUGGING ==: Is News Article") if $config->{'debug'};
            my $author   = $article_struct->{'info'}->{'author'};
            my $category = $article_struct->{'info'}->{'category'};
            my $date     = $article_struct->{'info'}->{'date'};
            my $title    = $article_struct->{'title'};
            my $content  = $article_struct->{'content'};
            my $id       = $article_struct->{'id'};

            return $author, ucfirst($category), $date, $title, $content, $id;
        } elsif ($type eq 'bio') {
            $logger->err_log("== DEBUGGING ==: Is Guest Bio") if $config->{'debug'};
            my $name     = $article_struct->{'name'};
            my %bio_info;
            my @bios     = ();
            foreach my $bio (@{$article_struct->{'bios'}}) {
                $logger->err_log("== TRACE ==: bio dump:" . Dumper($bio)) if $config->{'trace'};
                $bio_info{'photoFileName'} = $bio->{'photoFileName'};
                $bio_info{'position'}      = $bio->{'photoPosition'};
                $bio_info{'content'}       = $bio->{'content'};
                # get the mtime of the photo in UNIX time
                my $f_mtime  = get_mtime($bio_info{'photoFileName'});
                # to work around caching issues with Chrome, append a query string to the
                # file URL with the mtime
                $logger->err_log("== DEBUGGING ==: photo MTIME: ". $f_mtime) if $config->{'debug'};
                $bio_info{'photoFileName'} = $bio_info{'photoFileName'} . "?${f_mtime}";
                push(@bios, {%bio_info});
            }

            $logger->err_log("== TRACE ==: bios data dump: ". Dumper(@bios)) if $config->{'trace'} ;

            return ($name, @bios);
        }
    }

    my sub get_file_list :ReturnType(list => Str) ($directory, $extension) {
        type_check($directory, Str);
        type_check($extension, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my @files;
        opendir(my $dh, "$directory");
        while (my $file = readdir $dh) {
            next if $file =~ /^\.\.?$/;
            next if $file !~ /^\d+\.json$/;
            $logger->err_log("== DEBUGGING ==: File '$file' found. Will add to array.") if $config->{'debug'};
            push(@files, "$directory/$file");
        }
        closedir $dh;

        return @files;
    }

    my sub build_menus_struct :ReturnType(Void) ($json_path) {
        type_check($json_path, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $struct = undef;
        my $appdir = $config->{'appdir'};
        $logger->err_log("== DEBUGGING ==: Menu definition directory: ${appdir}${json_path}");
        my @files  = sort(get_file_list("${appdir}${json_path}", "json"));

        foreach my $file (@files) {
            $logger->err_log("== DEBUGGING ==: file: $file") if $config->{'debug'};
            my $fh = undef;
            my $status = undef;
            try {
                ($fh, $status) = $fio->open('r', $file);
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };
            try {
                $status = $fio->close($fh);
            } catch {
                $err->err_msg($status, __PACKAGE__);
            };
        }

        return $struct;
    }

    my sub build_article_struct_list :ReturnType(ArrayRef[HashRef]) () {
        my $appdir = $config->{'appdir'};
        my @files = sort { $b cmp $a } get_file_list("${appdir}content", 'json');

        my @articles;
        foreach my $file (@files) {
            $logger->err_log("== DEBUGGING ==: Processing file '$file'") if $config->{'debug'};
            my (undef, $filename) = split(/.*\/content\//, $file);
            $logger->err_log("== DEBUGGING ==: filename '$filename'") if $config->{'debug'};
            my ($article, $ext) = split(/\./, $filename);
            my ($author, $category, $date, $title, $content, $id) = get_article_from_json($article, 'news');
            push(@articles,
                {
                    'author'    => $author,
                    'category'  => $category,
                    'date'      => $date,
                    'title'     => $title,
                    'content'   => $content,
                    'id'        => $id
                }
            );
        }

        return \@articles;
    }

    my sub get_department_contacts :ReturnType(HashRef) ($appdir) {
        type_check($appdir, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt = get_json("conf.d/departments.json");
        my $json     = JSON->new();
        my $people   = undef;
        try {
            $people   = $json->decode($json_txt) or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, 'departments.json'",
                    'info'         => "Attempted to decode JSON content from 'departments.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };

        $logger->err_log("== TRACE ==: DUMP: ". Dumper($people)) if $config->{'trace'};
        return $people;
    }

    my sub get_guestlist :ReturnType(HashRef) ($appdir) {
        type_check($appdir, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt = get_json("conf.d/features.json");
        my $json     = JSON->new();
        my $guests   = undef;
        try {
            $guests  = $json->decode($json_txt)->{'guestList'} or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, 'features.json'",
                    'info'         => "Attempted to decode JSON content from 'features.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };

        return $guests;
    }

    my sub get_artist_list :ReturnType(HashRef) ($appdir) {
        type_check($appdir, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt = get_json("content/artists/artists.json");
        my $json     = JSON->new();
        my $artists  = undef;
        try {
            $artists = $json->decode($json_txt)->{'artists'} or 
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file. 'artists.json'",
                    'info'         => "Attempted to decode JSON content from 'artists.json'"
                }
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            }
        };

        return $artists;
    }

    my sub get_vendor_list :ReturnType(HashRef) ($appdir) {
        type_check($appdir, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt = get_json("content/vendors/vendors.json");
        my $json     = JSON->new();
        my $vendors  = undef;
        try {
            $vendors = $json->decode($json_txt)->{'vendors'} or 
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file. 'vendors.json'",
                    'info'         => "Attempted to decode JSON content from 'vendors.json'"
                }
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            }
        };

        return $vendors;
    }

    my sub get_panel_details :ReturnType(HashRef) ($appdir) {
        type_check($appdir, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt = get_json("content/panels/panels.json");
        my $json     = JSON->new();
        my $panels  = undef;
        try {
            $panels = $json->decode($json_txt)->{'panels'} or 
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file. 'vendors.json'",
                    'info'         => "Attempted to decode JSON content from 'vendors.json'"
                }
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            }
        };

        return $panels;
    }

    my sub get_department_email_from_id :ReturnType(Str) ($appdir, $value) {
        type_check($appdir, Str);
        type_check($value, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Input \$value: $value") if $config->{'debug'};

        my $person;
        my @people = @{get_department_contacts($appdir)};

        foreach $person (@people) {
            $logger->err_log("== DEBUGGING ==: Id: $person->{'id'}") if $config->{'debug'};
            if ($person->{'id'} == $value) {
                $logger->err_log("== DEBUGGING ==: Id \$person->{'id'} equals '$value'. Retrieving email address") if $config->{'debug'};
                $logger->err_log("== DEBUGGING ==: Id: $value, Email: $person->{'emailAddress'}") if $config->{'debug'};
                return $person->{'emailAddress'};
            } else {
                $logger->err_log("== DEBUGGING ==: Id does not match value. Continuing...") if $config->{'debug'};
            }
        }

        return undef;
    }

    my sub validate_recaptcha :ReturnType(Bool) ($response_data) {
        type_check($response_data, Str);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        # build an LWP::UserAgent object
        my $ua = LWP::UserAgent->new();
        $ua->agent("BuyoContentManager/reCAPTCHA/$VERSION");

        my $secret_key = $config->{'service_key'};
        # create our post request to Google
        my $url     = 'https://www.google.com/recaptcha/api/siteverify';
        my $uri_enc = URI::Encode->new(encode_reserved => 0);
        $logger->err_log("== DEBUGGING ==: config dump: ". Dumper($config)) if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: secret key: $secret_key") if $config->{'debug'};
        my $encoded_service_key = $uri_enc->encode($secret_key);
        $logger->err_log("== DEBUGGING ==: encoded service key: $encoded_service_key") if $config->{'debug'};
        my $encoded_response    = $uri_enc->encode($response_data);
        $logger->err_log("== DEBUGGING ==: response: $response_data") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: encoded response: $encoded_response") if $config->{'debug'};
        my $query   = '?secret=' . $secret_key . '&response=' . $response_data;
        $logger->err_log("== DEBUGGING ==: query string: $query") if $config->{'debug'};
        my $req     = HTTP::Request->new(POST => "${url}${query}");
        $req->content_type('application/x-www-form-urlencoded');
        $req->header('Content-Length' => 0);
        my $result  = $ua->request($req);
        $logger->err_log("== DEBUGGING ==: response: ". Dumper($result)) if $config->{'debug'};
        my $js_res  = decode_json($result->content);
        $logger->err_log("== DEBUGGING ==: decoded response: ". Dumper($js_res)) if $config->{'debug'};

        if ($js_res->{'success'} eq 'true') {
            return true;
        } else {
            return false;
        }
    }

    my sub send_email :ReturnType(Void) ($post_values) {
        type_check($post_values, HashRef);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        $logger->err_log("== TRACE ==: DUMP POST VALUES: ". Dumper($post_values)) if $config->{'trace'};
        my $email_address = get_department_email_from_id($config->{'appdir'}, $post_values->{'to_list'});
        my $email_subject = $post_values->{'email_subject'};
        my $email_body    = "Message sent from: $post_values->{'email_address'}\n\nMessage:\n$post_values->{'email_body'}\n";

        # validate that the user was real using the reCAPTCHA post data
        my $response      = validate_recaptcha($post_values->{'g-recaptcha-response'});

        if ($response eq true) {
            $logger->err_log("== DEBUGGING ==: The response was valid! Let's send an email") if $config->{'debug'};
            # construct email
            my $msg = MIME::Lite->new(
                From     => 'noreply@jafax.org',
                To       => $email_address,
                Subject  => $email_subject,
                Type     => 'TEXT',
                Encoding => 'quoted-printable',
                Data     => $email_body,
            );
            $msg->send('sendmail', '/usr/sbin/sendmail -t -oi -oem');
        } else {
            $logger->err_log("== WARNING ==: Got a bot posting stuff: email address ". $post_values->{'email_address'});
        }
    }

    my sub get_last_three_article_structs :ReturnType(ArrayRef[HashRef]) ($articles) {
        type_check($articles, ArrayRef[HashRef]);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        # first, cast $articles into an array
        my @articles = @{$articles};

        my $top_articles = undef;
        my $article_count = scalar(@articles);
        $logger->err_log("== DEBUGGING ==: Number of articles: $article_count") if $config->{'debug'};
        if ($article_count > 3) {
            $logger->err_log("== DEBUGGING ==: More than 3 articles") if $config->{'debug'};
            $top_articles = [
                $articles[0],
                $articles[1],
                $articles[2]
            ];
        } elsif (scalar(@articles) == 2) {
            $logger->err_log("== DEBUGGING ==: Only 2 articles") if $config->{'debug'};
            $top_articles = [ $articles[0], $articles[1] ];
        } else {
            $logger->err_log("== DEBUGGING ==: Only 1 article") if $config->{'debug'};
            $top_articles = [ $articles[0] ];
        }

        return $top_articles;
    }

    my sub validate_page_launch_date :ReturnType(Bool) ($launch_date, $curr_date) {
        type_check($launch_date, Int);
        type_check($curr_date, Int);

        my $do_launch = false;
        if ($curr_date >= $launch_date) {
            $do_launch = true;
        }

        return $do_launch;
    }

    my sub expire_page :ReturnType(Bool) ($expiry_date, $curr_date) {
        type_check($expiry_date, Int);
        type_check($curr_date, Int);

        my $expire = false;
        if ($expiry_date != -1) {
            if ($curr_date > $expiry_date) {
                $expire = true;
            }
        }

        return $expire;
    }

    my sub get_carousel_settings :ReturnType(ArrayRef[HashRef]) () {
        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $appdir   = $config->{'appdir'};
        my $json_txt = get_json("content/carousel/settings.json");
        my $json     = JSON->new();
        my $pages    = undef;
        try {
            $pages  = $json->decode($json_txt)->{'carouselPages'} or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, 'features.json'",
                    'info'         => "Attempted to decode JSON content from 'features.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };

        return $pages;
    }

    my sub register_dynamic_route :ReturnType(Str) ($verb, $bindings, $path) {
        type_check($verb, Str);
        type_check($bindings, HashRef);
        type_check($path, Str);

        # un-reference to make easier to work with
        my %bindings = %{$bindings};

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $class        = lc($bindings{$path}->{$verb}->{'class'});
        my $template     = lc($bindings{$path}->{$verb}->{'template'});

        my $guest_list   = get_guestlist($config->{'appdir'});
        my $cguest_list  = $config->{'culturalGuestList'};
        my $mguest_list  = $config->{'musicalGuestList'};
        my $sguest_list  = $config->{'guestJudgeList'};

        $logger->err_log("== DEBUGGING ==: Registering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Using template '$template' for path '$path'") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Path '$path' has class '$class' attribute") if $config->{'debug'};
        given ($verb) {
            when ('get') {
                given ($class) {
                    when ('news::article') {
                        my $article_author;
                        my $article_category;
                        my $article_content;
                        my $article_date;
                        my $article_title;
                        my $article_id;

                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $article  = route_parameters->get('article');
                            $logger->err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Generating page for article '$article'") if $config->{'debug'};
                            # gather up article information
                            # get article title
                            my $article_mech = uc($config->{'configuration'}->{'article_mech'});
                            $logger->err_log("== DEBUGGING ==: Using Article Content Mechanism '$article_mech'") if $config->{'debug'};
                            given ($article_mech) {
                                when ('JSON') {
                                    ($article_author, $article_category, $article_date,
                                        $article_title, $article_content, $article_id) = get_article_from_json($article, 'news');
                                    break;
                                }
                                default {
                                    $logger->err_log("== WARNING ==: Unknown Article Content Mechanism, '$article_mech'");
                                }
                            }
                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'author'             => $article_author,
                                'category'           => $article_category,
                                'date'               => $article_date,
                                'title'              => $article_title,
                                'page_content'       => $article_content,
                                'launch'             => $do_launch,
                                'expirePage'         => $expire_page,
                                'path'               => $path,
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list
                            };
                        };
                    }
                    when ('form::mailer') {
                        get "$path" => sub {
                            my $selected_dept;
                            my $injected_subject;

                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $department = query_parameters->get('department');
                            my $subject    = query_parameters->get('sub');
                            my $people     = get_department_contacts($config->{'appdir'});
                            if (defined($department)) {
                                $selected_dept = $department;
                                $logger->err_log("== DEBUGGING ==: Form passed query parameter value '$department'") if $config->{'debug'};
                            }
                            if (defined($subject)) {
                                $injected_subject = $subject;
                                $logger->err_log("== DEBUGGING ==: Form passed query parameter value '$subject'") if $config->{'debug'};
                            }
                            $logger->err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Generating page for '$class'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: reCAPTCHA site key: ". $config->{'site_key'});
                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'selected'           => $selected_dept,
                                'subject'            => $injected_subject,
                                'people'             => $people,
                                'launch'             => $do_launch,
                                'expirePage'         => $expire_page,
                                'path'               => $path,
                                'site_key'           => $config->{'site_key'},
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list
                            };
                        };
                    }
                    when ('news::aggregator') {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $articles = build_article_struct_list();
                            $logger->err_log("== DEBUGGING ==: Triggerng '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Generating page for '$class'") if $config->{'debug'};
                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'articles'           => $articles,
                                'launch'             => $do_launch,
                                'expirePage'         => $expire_page,
                                'path'               => $path,
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list
                            }
                        };
                    }
                    when ('news::highlights') {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $articles = build_article_struct_list();
                            my $top_three = get_last_three_article_structs($articles);
                            $logger->err_log("== DEBUGGING ==: Top Three structure: " . Dumper $top_three) if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Generating page for '$class'") if $config->{'debug'};
                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'articles'           => $top_three,
                                'launch'             => $do_launch,
                                'expirePage'         => $expire_page,
                                'path'               => $path,
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list
                            }
                        };
                    }
                    when ('guest::bio') {
                        get "$path" => sub {
                            my $bio_name;
                            my @bios;

                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $person = route_parameters->get('person');
                            $logger->err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Generating page for article '$person'") if $config->{'debug'};
                            my $page_content_mech = uc($config->{'configuration'}->{'article_mech'});
                            $logger->err_log("== DEBUGGING ==: Using Article Content Mechanism '$page_content_mech'") if $config->{'debug'};
                            given ($page_content_mech) {
                                when ('JSON') {
                                    ($bio_name, @bios) = get_article_from_json($person, 'bio');
                                    $logger->err_log("== TRACE ==: bios array dump: ". Dumper(@bios)) if $config->{'trace'};
                                    break;
                                }
                                default {
                                    $logger->err_log("== WARNING ==: Unknown Article Content Mechanism, '$page_content_mech'");
                                }
                            }
                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'name'               => $bio_name,
                                'bios'               => \@bios,
                                'launch'             => $do_launch,
                                'expirePage'         => $expire_page,
                                'path'               => $path,
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list
                            };
                        };
                    }
                    when ('widget::carousel') {
                        get "$path" => sub {
                            $logger->err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: Generating page for IFRAME") if $config->{'debug'};
                            my $carousel_settings = get_carousel_settings();
                            return template $template, {
                                'carouselPages'     => $carousel_settings
                            }, { layout => "carousel" };
                        };
                    }
                }   
            }
            when ('put') {}
            when ('post') {}
        }
    }

    my sub register_static_route :ReturnType(Str) ($verb, $bindings, $path) {
        type_check($verb, Str);
        type_check($bindings, HashRef);
        type_check($path, Str);

        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $class = lc($bindings{$path}->{$verb}->{'class'});
        my $template = $bindings{$path}->{$verb}->{'template'};

        my $guest_list   = get_guestlist($config->{'appdir'});
        my $cguest_list  = $config->{'culturalGuestList'};
        my $mguest_list  = $config->{'musicalGuestList'};
        my $sguest_list  = $config->{'guestJudgeList'};
        my $artists      = $config->{'artistsList'};
        my $vendors      = $config->{'vendorList'};
        my $panels       = $config->{'panelDescriptions'};

        $logger->err_log("== DEBUGGING ==: Registering " . uc($verb) . " action for path '$path'") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Using template '$template' for path '$path'") if $config->{'debug'};

        given ($verb) {
            when ('get') {
                given ($class) {
                    when ('form::authentication') {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            $logger->err_log("== DEBUGGING ==: Triggering ". uc($verb) . " action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: do_launch: $do_launch") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: expire_page: $expire_page") if $config->{'debug'};

                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'launch'             => $do_launch,
                                'expire_page'        => $expire_page,
                                'path'               => $path,
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list
                            }, { layout => 'login' };
                        };
                    }
                    default {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            $logger->err_log("== DEBUGGING ==: Triggering ". uc($verb) . " action for path '$path'") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: do_launch: $do_launch") if $config->{'debug'};
                            $logger->err_log("== DEBUGGING ==: expire_page: $expire_page") if $config->{'debug'};

                            $logger->err_log("== DEBUGGING ==: PANELS DUMP: ". Dumper($panels)) if $config->{'debug'};

                            return template $template, {
                                'webroot'            => $config->{'webroot'},
                                'site_name'          => $config->{'site_title'},
                                'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'          => $config->{'copyright'},
                                'license'            => $config->{'license'},
                                'launch'             => $do_launch,
                                'expire_page'        => $expire_page,
                                'path'               => $path,
                                'guests'             => $config->{'guests'},
                                'guestList'          => $guest_list,
                                'guestJudgeList'     => $sguest_list,
                                'culturalGuestList'  => $cguest_list,
                                'musicalGuestList'   => $mguest_list,
                                'artists'            => $artists,
                                'vendors'            => $vendors,
                                'panels'             => $panels
                            };
                        };
                    }
                }
            }
            when ('put') {}
            when ('post') {}
        }
    }

    my sub register_actor_route :ReturnType(Str) ($verb, $bindings, $path) {
        type_check($verb, Str);
        type_check($bindings, HashRef);
        type_check($path, Str);

        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $template;
        my $class     = lc($bindings{$path}->{$verb}->{'class'});
        if (defined($bindings{$path}->{$verb}->{'template'})) {
            $template = lc($bindings{$path}->{$verb}->{'template'});
        } else {
            $template = 'NULL';
        }

        my $guest_list   = get_guestlist($config->{'appdir'});
        my $cguest_list  = $config->{'culturalGuestList'};
        my $mguest_list  = $config->{'musicalGuestList'};
        my $sguest_list  = $config->{'guestJudgeList'};

        $logger->err_log("== DEBUGGING ==: Registering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Using template '$template' for path '$path'") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Path '$path' has class '$class' attribute") if $config->{'debug'};

        given ($verb) {
            when ('post') {
                given ($class) {
                    when ('action::mailer') {
                        post "$path" => sub {
                            my $post_values = request->params;

                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            $logger->err_log("== DEBUGGING ==: Triggering '$verb' action for path '$path'") if $config->{'debug'};
                            send_email($post_values);
                            if ($template ne 'NULL') {
                                return template $template, {
                                    'webroot'            => $config->{'webroot'},
                                    'site_name'          => $config->{'site_title'},
                                    'page_title'         => $bindings->{$path}->{'get'}->{'summary'},
                                    'copyright'          => $config->{'copyright'},
                                    'license'            => $config->{'license'},
                                    'launch'             => $do_launch,
                                    'expirePage'         => $expire_page,
                                    'path'               => $path,
                                    'guests'             => $config->{'guests'},
                                    'guestList'          => $guest_list,
                                    'guestJudgeList'     => $sguest_list,
                                    'culturalGuestList'  => $cguest_list,
                                    'musicalGuestList'   => $mguest_list
                                };
                            }
                        };
                    }
                }
            }
            when ('get') {}
            when ('put') {}
        }

        return true;
    }

    my sub register_get_routes :ReturnType(Bool) ($bindings, @paths) {
        type_check($bindings, HashRef);
        type_check(\@paths, ArrayRef[Str]);

        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        foreach my $path (@paths) {
            my $type = $bindings{$path}->{'get'}->{'type'};
            if (defined($type)) {
                $logger->err_log("== DEBUGGING ==: Path '$path' has type: '$type'") if $config->{'debug'};
            } else {
                $logger->err_log("== DEBUGGING ==: Path '$path' has no defined type!") if $config->{'debug'};
            }
            given ($type) {
                when ('dynamic') {
                    register_dynamic_route('get', $bindings, $path);
                }
                when ('static') {
                    register_static_route('get', $bindings, $path);
                }
                when ('actor') {
                    register_actor_route('get', $bindings, $path);
                }
            }
        }

        return true;
    }

    my sub register_post_routes :ReturnType(Bool) ($bindings, @paths) {
        type_check($bindings, HashRef);
        type_check(\@paths, ArrayRef[Str]);

        my $sub = (caller(0))[3];
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my %bindings = %$bindings;

        foreach my $path (@paths) {
            my $type = $bindings{$path}->{'post'}->{'type'};
            if (defined($type)) {
                $logger->err_log("== DEBUGGING ==: Path '$path' has type: '$type'") if $config->{'debug'};
            } else {
                $logger->err_log("== DEBUGGING ==: Path '$path' has no defined type!") if $config->{'debug'};
            }
            given ($type) {
                when ('dynamic') {
                    register_dynamic_route('post', $bindings, $path);
                }
                when ('static')  {
                    register_static_route('post', $bindings, $path);
                }
                when ('actor')   {
                    register_actor_route('post', $bindings, $path);
                }   
            }
        }

        return true;
    }

    our sub main :ReturnType(Void) (@args) {
        type_check(\@args, ArrayRef[Str]);

        my $sub = (caller(0))[3];

        set traces  => 1;

        my %configuration = load_config(config->{appdir});

        my @getters;
        my @posters;

        # this is a global, so this updates the outer scoped version
        $config = {
            'appdir'        => config->{appdir},
            'article_mech'  => $configuration{'article_mech'},
            'debug'         => $configuration{'debug'},
            'trace'         => $configuration{'trace'},
            'site_key'      => $configuration{'site_key'},
            'service_key'   => $configuration{'service_key'},
            'configuration' => \%configuration
        };

        $logger = Buyo::Logger->new({'debug' => $config->{'debug'},
                                     'trace' => $config->{'trace'}});
        $logger->err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};
        $logger->err_log("== DEBUGGING ==: Loading Sys::Error") if $config->{'debug'};
        $err = Sys::Error->new();
        $logger->err_log("== DEBUGGING ==: Loading File::IO") if $config->{'debug'};
        $fio = File::IO->new();

        my $json_txt     = get_json("conf.d/bindings.json");
        my $features_jsn = get_json("conf.d/features.json");
        my $json         = JSON->new();

        my $menus_struct = build_menus_struct("content/menu");

        my $data         = undef;
        try {
            $data        = $json->decode($json_txt) or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, 'bindings.json'",
                    'info'         => "Attempted to decode JSON content from 'bindings.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };
        my $features = undef;
        try {
            $features = $json->decode($features_jsn) or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, 'features.json'",
                    'info'         => "Attempted to decode JSON content from 'features.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    $logger->error_msg($ARG, "Default error");
                }
            };
        };

        $config->{'site_title'}         = $data->{'info'}->{'title'};
        $config->{'copyright'}          = $data->{'info'}->{'copyright'};
        $config->{'license'}            = $data->{'info'}->{'license'};
        $config->{'guests'}             = $features->{'guests'};
        $config->{'guestList'}          = $features->{'guestList'};
        $config->{'musicalGuestList'}   = $features->{'musicalGuestList'};
        $config->{'culturalGuestList'}  = $features->{'culturalGuestList'};
        $config->{'guestJudgeList'}     = $features->{'guestJudgeList'};
        $config->{'artistsList'}        = get_artist_list($config->{'appdir'});
        $config->{'vendorList'}         = get_vendor_list($config->{'appdir'});
        $config->{'panelDescriptions'}  = get_panel_details($config->{'appdir'});

        $logger->err_log("== TRACE ==: DUMP: ". Dumper($config)) if $config->{'trace'};

        my %paths = %{$data->{'paths'}};

        $logger->err_log('== DEBUGGING ==: Loading site endpoints from JSON:') if $config->{'debug'};
        foreach my $path (keys %paths) {
            $logger->err_log("== DEBUGGING ==: FOUND KEY: $path") if $config->{'debug'};
            if (exists $paths{$path}->{'get'}) {
                if ($paths{$path}->{'get'}->{'active'} eq 'true') {
                    push @getters, $path;
                }
            }
            if (exists $paths{$path}->{'post'}) {
                if ($paths{$path}->{'post'}->{'active'} eq 'true') {
                    push @posters, $path;
                }
            }
        }

        register_get_routes(\%paths, @getters);
        register_post_routes(\%paths, @posters);
    }

    main(@ARGV);

    true;
}
