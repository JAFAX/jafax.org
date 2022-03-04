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

package Buyo {
    use strictures;
    use English qw(-no_match_vars);
    use utf8;

    use boolean qw(:all);
    use CGI::Carp qw(carp croak fatalsToBrowser);
    use Config::IniFiles;
    use Dancer2;
    use JSON qw();
    use Data::Dumper;
    use LWP::UserAgent;
    use MIME::Lite;
    use URI::Encode;
    use Try::Tiny qw(try catch);
    use Throw qw(throw classify);

    use feature ":5.26";
    use feature 'lexical_subs';
    use feature 'signatures';
    use feature 'switch';
    no warnings "experimental::signatures";
    no warnings "experimental::smartmatch";

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Buyo::Constants;
    use Buyo::Utils qw(err_log);

    my $VERSION = $Buyo::Constants::VERSION;

    # this global is to avoid copying it everywhere
    our $config;

    my sub error_msg ($error_struct, $class) {
        say STDERR "Error struct dump: ". Dumper($error_struct);

        my $error   = $error_struct->{'error'};
        my $info    = $error_struct->{'info'};
        my $log_msg = $error_struct->{'log_message'};
        my $type    = $error_struct->{'type'};
        my $err_str = $error_struct->{'error_string'};

        my $msg = "== ERROR ==: $error: $class\n" .
                  "== ERROR ==: $info\n" .
                  "== ERROR ==: $log_msg\n" .
                  "== ERROR ==: error type: $type, $err_str\n";
        croak($msg);
    }

    my sub load_config {
        my $sub = (caller(0))[3];
        my $appdir = shift;

        my $ini_file = "$appdir/conf.d/config.ini";

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
                    error_msg($ARG, "File not found");
                },
                13      => sub {
                    error_msg($ARG, "Access denied");
                },
                default => sub {
                    error_msg($ARG, "Default error");
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
                    error_msg($ARG, "Cannot parse");
                },
                default => sub {
                    error_msg($ARG, "Default error");
                }
            };
        };

        my %configuration = ();

        $configuration{'debug'}           = $cfg->val('General', 'debugging');
        $configuration{'webroot'}         = $cfg->val('Web', 'webpath');
        $configuration{'session_support'} = $cfg->val('Web', 'session_support', 0);
        $configuration{'article_mech'}    = $cfg->val('Web', 'article_mech', "JSON");
        $configuration{'etcd_user'}       = $cfg->val('etcd', 'user');
        $configuration{'etcd_password'}   = $cfg->val('etcd', 'pass');
        $configuration{'site_key'}        = $cfg->val('reCAPTCHA', 'site_key');

        err_log("== DEBUGGING ==: Config DUMP: ". Dumper(%configuration));

        return %configuration;
    }

    my sub get_json ($json_file) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        err_log("== DEBUGGING ==: APPDIR: $config->{'appdir'}") if $config->{'debug'};
        err_log("== DEBUGGING ==: JSON FILE: $json_file") if $config->{'debug'};

        my $fh = undef;
        my $json_txt = undef;
        my $file_full_path = "$config->{'appdir'}/$json_file";
        try {
            open $fh, '<', $file_full_path or
              throw "File IO error", {
                'type'         => int($OS_ERROR),
                'error_string' => $OS_ERROR,
                'log_msg'      => "Could not read bindings configuration: $OS_ERROR",
                'info'         => "Attempted to open '$file_full_path' for read"
            };
        } catch {
            classify $ARG, {
                2       => sub {
                    error_msg($ARG, "File not found");
                },
                13      => sub {
                    error_msg($ARG, "Access denied");
                },
                default => sub {
                    error_msg($ARG, "Default error");
                }
            };
        };
        try {
            read $fh, $json_txt, -s $fh or
              throw "File IO error", {
                'type'         => int($OS_ERROR),
                'error_string' => $OS_ERROR,
                'log_msg'      => "Could not read bindings configuration: $OS_ERROR",
                'info'         => "Attempted to read from filehandle"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    error_msg($ARG, "Default error");
                }
            };
        };
        try {
            close $fh or throw "FileHandle error", {
                'type'         => int($OS_ERROR),
                'error_string' => $OS_ERROR,
                'log_msg'      => "Could not close filehandle: $OS_ERROR",
                'info'         => "Attempted to close filehandle for '$file_full_path'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    error_msg($ARG, "Default error");
                }
            };
        };

        return $json_txt;
    }

    my sub get_article_from_json ($article, $type) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

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
                    error_msg($ARG, "Default error");
                }
            };
        };

        if ($type eq 'news') {
            my $author   = $article_struct->{'info'}->{'author'};
            my $category = $article_struct->{'info'}->{'category'};
            my $date     = $article_struct->{'info'}->{'date'};
            my $title    = $article_struct->{'title'};
            my $content  = $article_struct->{'content'};
            my $id       = $article_struct->{'id'};

            return $author, ucfirst($category), $date, $title, $content, $id;
        } elsif ($type eq 'bio') {
            my $name     = $article_struct->{'name'};
            my $photo_fn = $article_struct->{'photoFileName'};
            my $position = $article_struct->{'photoPosition'};
            my $content  = $article_struct->{'content'};

            return $name, $photo_fn, $position, $content;
        }
    }

    my sub get_file_list ($directory, $extension) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my @files;
        opendir(my $dh, "$config->{'appdir'}$directory");
        while (my $file = readdir $dh) {
            next if $file =~ /^\.\.?$/;
            next if $file !~ /^\d+\.json$/;
            err_log("== DEBUGGING ==: File '$file' found. Will add to array.") if $config->{'debug'};
            push(@files, "$config->{'appdir'}$directory/$file");
        }
        closedir $dh;

        return @files;
    }

    my sub build_article_struct_list () {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my @files = sort { $b cmp $a} get_file_list('content', 'json');

        my @articles;
        foreach my $file (@files) {
            err_log("== DEBUGGING ==: Processing file '$file'") if $config->{'debug'};
            my (undef, $filename) = split(/.*\/content\//, $file);
            err_log("== DEBUGGING ==: filename '$filename'") if $config->{'debug'};
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

    my sub get_department_contacts ($appdir) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $json_txt = get_json("departments.json");
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
                    error_msg($ARG, "Default error");
                }
            };
        };

        return $people;
    }

    my sub get_department_email_from_id ($appdir, $value) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};
        err_log("== DEBUGGING ==: Input \$value: $value") if $config->{'debug'};

        my $person;
        my @people = @{get_department_contacts($appdir)};

        foreach $person (@people) {
            err_log("== DEBUGGING ==: Id: $person->{'id'}") if $config->{'debug'};
            if ($person->{'id'} == $value) {
                err_log("== DEBUGGING ==: Id \$person->{'id'} equals '$value'. Retrieving email address") if $config->{'debug'};
                return $person->{'emailAddress'};
            } else {
                err_log("== DEBUGGING ==: Id does not match value. Continuing...") if $config->{'debug'};
            }
        }

        return undef;
    }

    my sub validate_recaptcha ($response_data) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        # build an LWP::UserAgent object
        my $ua = LWP::UserAgent->new();
        $ua->agent("Buyo Content Manager/$VERSION");

        my $secret_key = $config->{'service_key'};
        # create our post request to Google
        my $url     = 'https://www.google.com/recaptcha/api/siteverify';
        my $uri_enc = URI::Encode->new(encode_reserved => 0);
        err_log("== DEBUGGING ==: config dump: ". Dumper($config)) if $config->{'debug'};
        err_log("== DEBUGGING ==: secret key: $secret_key") if $config->{'debug'};
        my $encoded_service_key = $uri_enc->encode($secret_key);
        my $encoded_response    = $uri_enc->encode($response_data);
        my $query   = '?secret=' . $encoded_service_key . '&response=' . $encoded_response;
        my $req     = HTTP::Request->new(POST => "${url}${query}");
        my $result  = $ua->request($req);
        my $js_res  = decode_json($result->content);

        if ($js_res->success eq 'true') {
            return true;
        } else {
            return false;
        }
    }

    my sub send_email ($post_values) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        err_log("== DEBUGGING ==: DUMP POST VALUES: ". Dumper($post_values)) if $config->{'debug'};
        my $email_address = get_department_email_from_id($config->{'appdir'}, $post_values->{'to_list'});
        my $email_subject = $post_values->{'email_subject'};
        my $email_body    = "Message sent from: $post_values->{'email_address'}\n\nMessage:\n$post_values->{'email_body'}\n";

        # validate that the user was real using the reCAPTCHA post data
        my $response      = validate_recaptcha($post_values->{'g-recaptcha-response'});

        if ($response eq true) {
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
            err_log("== WARNING ==: Got a bot posting stuff: email address ". $post_values->{'email_address'});
        }
    }

    my sub get_last_three_article_structs ($articles) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        # first, cast $articles into an array
        my @articles = @{$articles};

        my $top_articles = undef;
        if (scalar(@articles) ge 3) {
            $top_articles = [
                $articles[0],
                $articles[1],
                $articles[2]
            ];
        } elsif (scalar(@articles) eq 2) {
            $top_articles = [ $articles[0], $articles[1] ];
        } else {
            $top_articles = [ $articles[0] ];
        }

        return $top_articles;
    }

    my sub validate_page_launch_date ($launch_date, $curr_date) {
        my $do_launch = false;
        if ($curr_date >= $launch_date) {
            $do_launch = true;
        }

        return $do_launch;
    }

    my sub expire_page ($expiry_date, $curr_date) {
        my $expire = false;
        if ($expiry_date != -1) {
            if ($curr_date > $expiry_date) {
                $expire = true;
            }
        }

        return $expire;
    }

    my sub register_dynamic_route ($verb, $bindings, $path) {
        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $class        = lc($bindings{$path}->{$verb}->{'class'});
        my $template     = lc($bindings{$path}->{$verb}->{'template'});
        err_log("== DEBUGGING ==: Registering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
        err_log("== DEBUGGING ==: Using template '$template' for path '$path'") if $config->{'debug'};
        err_log("== DEBUGGING ==: Path '$path' has class '$class' attribute") if $config->{'debug'};
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
                            err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: Generating page for article '$article'") if $config->{'debug'};
                            # gather up article information
                            # get article title
                            my $article_mech = uc($config->{'configuration'}->{'article_mech'});
                            err_log("== DEBUGGING ==: Using Article Content Mechanism '$article_mech'") if $config->{'debug'};
                            given ($article_mech) {
                                when ('JSON') {
                                    ($article_author, $article_category, $article_date,
                                        $article_title, $article_content, $article_id) = get_article_from_json($article, 'news');
                                    break;
                                }
                                default {
                                    err_log("== WARNING ==: Unknown Article Content Mechanism, '$article_mech'");
                                }
                            }
                            return template $template, {
                                'webroot'       => $config->{'webroot'},
                                'site_name'     => $config->{'site_title'},
                                'page_title'    => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'     => $config->{'copyright'},
                                'license'       => $config->{'license'},
                                'author'        => $article_author,
                                'category'      => $article_category,
                                'date'          => $article_date,
                                'title'         => $article_title,
                                'page_content'  => $article_content,
                                'launch'        => $do_launch,
                                'expirePage'    => $expire_page,
                                'path'          => $path
                            };
                        };
                    }
                    when ('form::mailer') {
                        get "$path" => sub {
                            my $selected_dept;

                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $department = query_parameters->get('department');
                            my $people = get_department_contacts($config->{'appdir'});
                            if (defined($department)) {
                                $selected_dept = $department;
                                err_log("== DEBUGGING ==: Form passed query parameter value '$department'") if $config->{'debug'};
                            }
                            err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: Generating page for '$class'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: reCAPTCHA site key: ". $config->{'site_key'});
                            return template $template, {
                                'webroot'       => $config->{'webroot'},
                                'site_name'     => $config->{'site_title'},
                                'page_title'    => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'     => $config->{'copyright'},
                                'license'       => $config->{'license'},
                                'selected'      => $selected_dept,
                                'people'        => $people,
                                'launch'        => $do_launch,
                                'expirePage'    => $expire_page,
                                'path'          => $path,
                                'site_key'      => $config->{'site_key'}
                            };
                        };
                    }
                    when ('news::aggregator') {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $articles = build_article_struct_list();
                            err_log("== DEBUGGING ==: Triggerng '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: Generating page for '$class'") if $config->{'debug'};
                            return template $template, {
                                'webroot'       => $config->{'webroot'},
                                'site_name'     => $config->{'site_title'},
                                'page_title'    => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'     => $config->{'copyright'},
                                'license'       => $config->{'license'},
                                'articles'      => $articles,
                                'launch'        => $do_launch,
                                'expirePage'    => $expire_page,
                                'path'          => $path
                            }
                        };
                    }
                    when ('news::highlights') {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $articles = build_article_struct_list();
                            my $top_three = get_last_three_article_structs($articles);
                            err_log("== DEBUGGING ==: Top Three structure: " . Dumper $top_three) if $config->{'debug'};
                            err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: Generating page for '$class'") if $config->{'debug'};
                            return template $template, {
                                'webroot'       => $config->{'webroot'},
                                'site_name'     => $config->{'site_title'},
                                'page_title'    => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'     => $config->{'copyright'},
                                'license'       => $config->{'license'},
                                'articles'      => $top_three,
                                'launch'        => $do_launch,
                                'expirePage'    => $expire_page,
                                'path'          => $path
                            }
                        };
                    }
                    when ("guest::bio") {
                        get "$path" => sub {
                            my $bio_name;
                            my $bio_photo;
                            my $bio_photo_position,
                            my $bio_content;

                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            my $person = route_parameters->get('person');
                            err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: Generating page for article '$person'") if $config->{'debug'};
                            my $page_content_mech = uc($config->{'configuration'}->{'article_mech'});
                            err_log("== DEBUGGING ==: Using Article Content Mechanism '$page_content_mech'") if $config->{'debug'};
                            given ($page_content_mech) {
                                when ('JSON') {
                                    ($bio_name, $bio_photo, $bio_photo_position, $bio_content) = get_article_from_json($person, 'bio');
                                    break;
                                }
                                default {
                                    err_log("== WARNING ==: Unknown Article Content Mechanism, '$page_content_mech'");
                                }
                            }
                            return template $template, {
                                'webroot'       => $config->{'webroot'},
                                'site_name'     => $config->{'site_title'},
                                'page_title'    => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'     => $config->{'copyright'},
                                'license'       => $config->{'license'},
                                'name'          => $bio_name,
                                'photo_uri'     => $bio_photo,
                                'position'      => $bio_photo_position,
                                'page_content'  => $bio_content,
                                'launch'        => $do_launch,
                                'expirePage'    => $expire_page,
                                'path'          => $path
                            };
                        };
                    }
                    when ("widget::carousel") {
                        get "$path" => sub {
                            err_log("== DEBUGGING ==: Triggering '" . uc($verb) . "' action for '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: Generating page for IFRAME") if $config->{'debug'};
                            return template $template, {}, { layout => "carousel" };
                        };
                    }
                }   
            }
            when ('put') {}
            when ('post') {}
        }
    }

    my sub register_static_route ($verb, $bindings, $path) {
        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $class = lc($bindings{$path}->{$verb}->{'class'});
        my $template = $bindings{$path}->{$verb}->{'template'};
        err_log("== DEBUGGING ==: Registering " . uc($verb) . " action for path '$path'") if $config->{'debug'};
        err_log("== DEBUGGING ==: Using template '$template' for path '$path'") if $config->{'debug'};

        given ($verb) {
            when ('get') {
                given ($class) {
                    when ('form::authentication') {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            err_log("== DEBUGGING ==: Triggering ". uc($verb) . " action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: do_launch: $do_launch") if $config->{'debug'};
                            err_log("== DEBUGGING ==: expire_page: $expire_page") if $config->{'debug'};

                            return template $template, {
                                'webroot'     => $config->{'webroot'},
                                'site_name'   => $config->{'site_title'},
                                'page_title'  => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'   => $config->{'copyright'},
                                'license'     => $config->{'license'},
                                'launch'      => $do_launch,
                                'expire_page' => $expire_page,
                                'path'        => $path
                            }, { layout => 'login' };
                        };
                    }
                    default {
                        get "$path" => sub {
                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            err_log("== DEBUGGING ==: Triggering ". uc($verb) . " action for path '$path'") if $config->{'debug'};
                            err_log("== DEBUGGING ==: do_launch: $do_launch") if $config->{'debug'};
                            err_log("== DEBUGGING ==: expire_page: $expire_page") if $config->{'debug'};

                            return template $template, {
                                'webroot'     => $config->{'webroot'},
                                'site_name'   => $config->{'site_title'},
                                'page_title'  => $bindings->{$path}->{'get'}->{'summary'},
                                'copyright'   => $config->{'copyright'},
                                'license'     => $config->{'license'},
                                'launch'      => $do_launch,
                                'expire_page' => $expire_page,
                                'path'        => $path
                            };
                        };
                    }
                }
            }
            when ('put') {}
            when ('post') {}
        }
    }

    my sub register_actor_route ($verb, $bindings, $path) {
        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my $template;
        my $class     = lc($bindings{$path}->{$verb}->{'class'});
        if (defined($bindings{$path}->{$verb}->{'template'})) {
            $template = lc($bindings{$path}->{$verb}->{'template'});
        } else {
            $template = 'NULL';
        }
        err_log("== DEBUGGING ==: Registering '" . uc($verb) . "' action for path '$path'") if $config->{'debug'};
        err_log("== DEBUGGING ==: Using template '$template' for path '$path'") if $config->{'debug'};
        err_log("== DEBUGGING ==: Path '$path' has class '$class' attribute") if $config->{'debug'};

        given ($verb) {
            when ('post') {
                given ($class) {
                    when ('action::mailer') {
                        post "$path" => sub {
                            my $post_values = request->params;

                            my $do_launch = validate_page_launch_date($bindings{$path}->{$verb}->{'launchDate'}, time);
                            my $expire_page = expire_page($bindings{$path}->{$verb}->{'expireDate'}, time);

                            err_log("== DEBUGGING ==: Triggering '$verb' action for path '$path'") if $config->{'debug'};
                            send_email($post_values);
                            if ($template ne 'NULL') {
                                return template $template, {
                                    'webroot'    => $config->{'webroot'},
                                    'site_name'  => $config->{'site_title'},
                                    'page_title' => $bindings->{$path}->{'get'}->{'summary'},
                                    'copyright'  => $config->{'copyright'},
                                    'license'    => $config->{'license'},
                                    'launch'     => $do_launch,
                                    'expirePage' => $expire_page,
                                    'path'       => $path
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

    my sub register_get_routes ($bindings, @paths) {
        # un-reference to make easier to work with
        my %bindings = %$bindings;

        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        foreach my $path (@paths) {
            my $type = $bindings{$path}->{'get'}->{'type'};
            if (defined($type)) {
                err_log("== DEBUGGING ==: Path '$path' has type: '$type'") if $config->{'debug'};
            } else {
                err_log("== DEBUGGING ==: Path '$path' has no defined type!") if $config->{'debug'};
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

    my sub register_post_routes ($bindings, @paths) {
        my $sub = (caller(0))[3];
        err_log("== DEBUGGING ==: Sub: $sub") if $config->{'debug'};

        my %bindings = %$bindings;

        foreach my $path (@paths) {
            my $type = $bindings{$path}->{'post'}->{'type'};
            if (defined($type)) {
                err_log("== DEBUGGING ==: Path '$path' has type: '$type'") if $config->{'debug'};
            } else {
                err_log("== DEBUGGING ==: Path '$path' has no defined type!") if $config->{'debug'};
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

    our sub main (@args) {
        set traces  => 1;

        my %configuration = load_config(config->{appdir});

        my $sub = (caller(0))[3];

        my @getters;
        my @posters;

        # this is a global, so this updates the outer scoped version
        $config = {
            'appdir'        => config->{appdir},
            'article_mech'  => $configuration{'article_mech'},
            'debug'         => $configuration{'debug'},
            'site_key'      => $configuration{'site_key'},
            'service_key'   => $configuration{'service_key'},
            'configuration' => \%configuration
        };

        my $json_txt = get_json('bindings.json');
        my $json     = JSON->new();

        my $data     = undef;
        try {
            $data    = $json->decode($json_txt) or
                throw "JSON parsing error", {
                    'type'         => 1002,
                    'error_string' => "Cannot decode JSON file",
                    'log_msg'      => "Could not decode JSON file, 'bindings.json'",
                    'info'         => "Attempted to decode JSON content from 'bindings.json'"
            };
        } catch {
            classify $ARG, {
                default => sub {
                    error_msg($ARG, "Default error");
                }
            };
        };

        $config->{'site_title'} = $data->{'info'}->{'title'};
        $config->{'copyright'}  = $data->{'info'}->{'copyright'};
        $config->{'license'}    = $data->{'info'}->{'license'};

        my %paths = %{$data->{'paths'}};

        err_log("== DEBUGGING ==: Sub $sub") if $config->{'debug'};
        err_log('== DEBUGGING ==: Loading site endpoints from JSON:') if $config->{'debug'};
        foreach my $path (keys %paths) {
            err_log("== DEBUGGING ==: FOUND KEY: $path") if $config->{'debug'};
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

        return true;
    }

    main(@ARGV);

    true;
}
