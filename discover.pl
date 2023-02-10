#!/usr/bin/perl

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use LWP::UserAgent;
use Mojo::DOM;

use Mojolicious::Lite;
use URI;

use Web::Microformats2;

my $avatar_checks = ["icon", "shortcut icon", "apple-touch-icon", "apple-touch-icon-precomposed"];

sub canonicalize {
    my $url = shift;
    my $avatar = shift;

    if ($avatar =~ /^http:\/\/example.com/) {
        my $domain = URI->new($url)->host;
        my $scheme = URI->new($url)->scheme;
        $avatar = $scheme . "://" . $domain . ($avatar =~ s/^http:\/\/example.com//r);
        return $avatar;
    }

    # if doesn't start with http:// or https:// or //, then it's a relative path
    if ($avatar !~ /^http(s)?:\/\// && $avatar !~ /^\/\//) {
        my $domain = URI->new($url)->host;
        my $scheme = URI->new($url)->scheme;
        $avatar = $scheme . "://" . $domain . $avatar;
    }
    
    return $avatar;
}

sub traverse_links {
    my %all_rels = shift;
    my $links = shift;
    my $query = shift;
    my $main_url = shift;

    if ($links->size) {
        for my $link ($links->each) {
            my $rel = $link->attr('rel');
            my $url = $link->attr('href');

            if ($rel && $rel eq $query) {
                if ($all_rels{$rel}) {
                    push(@{$all_rels{$rel}}, canonicalize($main_url, $url));
                } else {
                    $all_rels{$rel} = [canonicalize($main_url, $url)];
                }
            }
        }
    }

    return \%all_rels;
}

sub discover_endpoints {
    my $ua = LWP::UserAgent->new;

    my $main_url = shift;
    my $query = "me"; #shift;

    my $domain = URI->new($main_url)->host;
    my $scheme = URI->new($main_url)->scheme;

    my $response = $ua->get($main_url);

    my $headers = $response->headers;

    my $link_headers = $headers->header('Link');

    my @links = split(/,/, $link_headers);

    my %all_rels;

    my @response = [];

    foreach my $link (@links) {
        my $new_link = $link;
        my $url = $link =~ s/.*<(.*)>.*/$1/r;
        my $rel = $link =~ s/.*rel='(.*)'.*/$1/r;
        
        if ($rel && $rel eq $query) {
            if ($all_rels{$rel}) {
                push(@{$all_rels{$rel}}, canonicalize($main_url, $url));
            } else {
                $all_rels{$rel} = [canonicalize($main_url, $url)];
            }
        }
    }

    my $dom = Mojo::DOM->new($response->decoded_content);

    my $a_links = $dom->find("a[rel*='$query']");
    my $all_links = $dom->find("link[rel*='$query']");

    %all_rels = %{traverse_links(\%all_rels, $a_links, $query, $main_url)};
    %all_rels = %{traverse_links(\%all_rels, $all_links, $query, $main_url)};

    return \%all_rels;
}

sub get_h_card {
    my $url = shift;

    my $ua = LWP::UserAgent->new;

    my $response = $ua->get($url);

    my $mf2_parser = Web::Microformats2::Parser->new;
    my $mf2_doc = $mf2_parser->parse( $response->decoded_content );

    my $avatar;

    my $h_card = $mf2_doc->get_first('h-card');

    if ($h_card) {
        $avatar = $h_card->get_property('photo');

        $avatar = canonicalize($url, $avatar);
    }

    return $avatar;
}

sub get_github_image {
    # if rel=me is github, then get the image from github

    my $rel_mes = shift;

    my $github_url;

    for my $rel_me (@$rel_mes) {
        if ($rel_me =~ /github.com/) {
            $github_url = $rel_me;
        }
    }

    return if !$github_url;

    my $ua = LWP::UserAgent->new;

    my $response = $ua->get($github_url . ".png");

    if ($response->is_success) {
        return $github_url . ".png";
    }
    
    return;
}

sub get_avatar {
    my $url = shift;

    my $h_card_avatar = get_h_card($url);

    if ($h_card_avatar) {
        return $h_card_avatar;
    }

    for my $avatar_check (@$avatar_checks) {
        my $rel_avatar = discover_endpoints($url, $avatar_check);

        if ($rel_avatar->{$avatar_check}) {
            return $rel_avatar->{$avatar_check}->[0];
        }
    }

    my $email = shift;

    if (!$email) {
        return;
    }

    my $gravatar_url = "https://www.gravatar.com/avatar/" . md5_hex($email) . "?d=404";

    my $ua = LWP::UserAgent->new;

    my $response = $ua->get($gravatar_url);

    if ($response->is_success) {
        return $gravatar_url;
    }

    my $endpoints = shift;

    my $rel_me = discover_endpoints($url, 'me');

    my $rel_me_urls = $rel_me->{'me'};

    my $github_image = get_github_image($rel_me_urls);

    if ($github_image) {
        return $github_image;
    }

    return;
}

get '/' => sub {
    my $c = shift;
    my $url = $c->param('url');
    my $email = $c->param('email');
    my $query = $c->param('query');
    my $endpoints = discover_endpoints($url, $query);
    my $avatar = get_avatar($url, $email);

    my $response = {
        # endpoints => $endpoints,
        avatar => $avatar
    };

    $c->render(json => $response);
};

app->start;