package MyParser;

use parent 'HTML::Parser';

use Data::Dumper;

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
    $self->{split_length} = $attr{split_length} or 20000;
    @wrap = ();
    @result = ();

    return $self;
}

sub start {
    my ($self, $tagname, $attr, $attrseq, $text) = @_;
#   print $text;
    if ($tagname !~ m/$ignore/) {
        push @wrap, { tagname => $tagname, attr => $attr, attrseq => $attrseq };
    }
    $self->{output} .= $text;
}

sub end {
    my ($self, $tagname, $text) = @_;
    my $endpos = scalar @wrap - 1;

    $self->{output} .= $text;

#   warn $tagname;

#   warn $endpos;
#warn $wrap[$endpos];

#   warn $tagname;
#warn $wrap[$endpos];

    if ($tagname !~ m/$ignore/) {
        if ($wrap[$endpos]->{tagname} eq $tagname) {
            pop @wrap;
        } else {
#           warn $endpos, $tagname;
#           warn Dumper @wrap;
        }
    }

    if ( length($self->{output}) > $self->{split_length}) {
        if ($tagname =~ m/^(div)$/) {
#               warn $endpos, $tagname;
#               warn Dumper @wrap;


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

# index > 1
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
warn $tmp;
        $tmp .= $_->{doc};

# closing content
        if ($i < scalar(@result)) {
            foreach my $leaf (@{$_->{wrap}}) {
                $tmp .= sprintf '</%s>', $leaf->{tagname};
                warn sprintf '</%s>', $leaf->{tagname};
            }
        }
        push @output, $tmp;
    }
    @output;
}

1;

