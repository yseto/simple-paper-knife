#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Dumper;
use File::Slurp;

use lib "lib/";
use MyParser;

#my $html = join "", <DATA>;
my $filename = shift;
die "cant read." unless -e $filename;
my $html = read_file($filename);

my $parser = MyParser->new(split_length => 5000);
$parser->parse($html);
$parser->eof;

my @res = $parser->output;

foreach (@res) {
    print "$_\n";
    print ("=" x 80);
    print "\n";
}

__END__

extract <body> to </body>
