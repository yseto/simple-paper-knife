package MyParser;

use strict;
use warnings;
use parent 'HTML::Parser';

use HTML::Entities;
use HTML::TreeBuilder;

our @wrap;
our @result;

my $ignore = qr/^(br|meta|link|html|head|img|hr)$/;

sub new {
    my ($class, %attr) = @_;
    my $self = $class->SUPER::new(
        api_version => 3,
        start_h     => [ \&start, 'self, tagname, attr, attrseq, text' ],
        end_h       => [ \&end,   'self, tagname, text' ],
        end_document_h => [ \&end_document,   'self' ],
        default_h   => [ sub { shift->{output} .= shift }, 'self, text'],
    );

    $self->{output} = '';
    $self->{split_length} = (defined $attr{split_length}) ? $attr{split_length} : 20000;
    $self->{repair_html} = (defined $attr{repair_html}) ? $attr{repair_html} : 1;
    @wrap = ();
    @result = ();

    return $self;
}

sub start {
    my ($self, $tagname, $attr, $attrseq, $text) = @_;
    if ($tagname !~ m/$ignore/) {
        push @wrap, { tagname => $tagname, attr => $attr, attrseq => $attrseq };
    }
    $self->{output} .= $text;
}

sub end {
    my ($self, $tagname, $text) = @_;
    my $endpos = scalar @wrap - 1;

    $self->{output} .= $text;

    if ($tagname !~ m/$ignore/) {
        if ($wrap[$endpos]->{tagname} eq $tagname) {
            pop @wrap;
        }
    }

    if ( length($self->{output}) > $self->{split_length}) {
        if ($tagname =~ m/^(div)$/) {
            push @result, { doc => $self->{output}, wrap => [@wrap], };
            $self->{output} = '';
        }
    }
}

sub end_document {
    my $self = shift;

    my $tmp = pop @result;
    $tmp->{doc} .= $self->{output};
    push @result, $tmp;
    $self->{output} = '';
}

sub output {
    my $self = shift;

    my @output;
    my $i = 0;
    foreach (@result) {
        $i++;
        my $tmp = '';
        if ($i > 1) {
            foreach my $leaf (@{$_->{wrap}}) {
                $tmp .= sprintf '<%s ', $leaf->{tagname};
                $tmp .= sprintf('%s="%s"', $_, $leaf->{attr}{$_}) for @{$leaf->{attrseq}};
                $tmp .= '>';
            }
        }
        $tmp .= $_->{doc};

# closing content
        if ($i < scalar(@result)) {
            foreach my $leaf (@{$_->{wrap}}) {
                $tmp .= sprintf '</%s>', $leaf->{tagname};
            }
        }
        push @output, ($self->{repair_html}) ? repair_html($tmp) : $tmp;
    }

    @output;
}

sub repair_html {
    my $html = shift;
    no strict 'refs';
    no warnings 'redefine';
    local *HTML::Entities::encode_entities = sub {};
    local *HTML::Entities::decode = sub {};
    my $output = HTML::TreeBuilder->new->parse($html)->as_HTML;
    $output =~ s#<html><head></head><body>##g;
    $output =~ s#</body>\s?</html>##g;
    $output =~ s#<div>(?:\&nbsp;)?</div>##ig;
    return $output;
}

1;

