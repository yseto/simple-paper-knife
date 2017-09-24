#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Section::Simple qw(get_data_section);
use Encode;
use Plack::Builder;
use Plack::Request;
use Template;
use URI;
use XML::Atom::Feed;

use lib "lib/";
use MyParser;

sub index {
    my $env = shift;

    my $req = Plack::Request->new($env);
    my @entries;
    my $body;
    my $link;
    my $title;

    if (my $atom = $req->param('atom')) {
        my $feed = XML::Atom::Feed->new(URI->new($atom));
        @entries = $feed->entries;
        $title = $feed->title;
    }

    if (defined $req->param('feedno')) {
        my $feedno = $req->param('feedno');
        if (defined $entries[$feedno]) {
            $body = $entries[$feedno]->content->body;
            $link = $entries[$feedno]->link->href;
            $title .= " - " . $entries[$feedno]->title;
        }
    }

    return [404, [], ["not found"]] unless $body;

    my $parser = MyParser->new(
        split_length => 5000,
        ((defined $req->param('mode')) ?  (repair_html => $req->param('mode')) : ())
    );
    $parser->parse($body);
    $parser->eof;
    my @res = $parser->output;

    my $page = $req->param('page') || 1;
    unless (defined $res[$page - 1]) {
        return [404, [], ["not found"]];
    }

    my $uri = URI->new($req->uri);
    my %param = $uri->query_form;
    delete $param{page};
    $uri->query_form(%param);

    tmpl(
        content => $res[$page - 1],
        page => $page,
        title => decode_utf8($title),
        total_page => [1 .. scalar(@res)],
        pager_base_url => $uri->as_string,
        link => $link,
    );
}

sub tmpl {
    my %arg = @_;
    my $tt = Template->new(ENCODING => 'utf-8');
    my $f = get_data_section('index.tt');
    $tt->process(\$f, \%arg, \my $out) or die $tt->error;
    $out = encode_utf8($out);
    return [200, ["Content-Type" =>"text/html;"], ["$out"]];
}

builder {
    enable 'ReverseProxy';
    mount '/index' => \&index;
};

__DATA__

@@ index.tt
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <title>Sample</title>
    <link href="http://getbootstrap.com/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="http://getbootstrap.com/docs/4.0/examples/narrow-jumbotron/narrow-jumbotron.css" rel="stylesheet">
  </head>
  <body>
    <div class="container">
      <div class="header clearfix">
        <h3 class="text-muted">simple-paper-knife</h3>
        <small><a href="https://www.google.com/url?sa=D&q=[% link %]" target="blank">[% link %]</a><br>[% title %]</small>
      </div>
      <div class="row">
        <div class="col-md-12">[% content %]</div>
        <nav aria-label="Page navigation example">
          <ul class="pagination">
[% FOREACH no IN total_page -%]
            <li class="page-item[% IF page == no %] active[% END %]">
              <a class="page-link" href="[% pager_base_url %]&page=[% no %]">[% no %]</a>
            </li>
[% END -%]
          </ul>
        </nav>
      </div>
    </div> <!-- /container -->
  </body>
</html>
