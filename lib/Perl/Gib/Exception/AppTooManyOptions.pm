package Perl::Gib::Exception::AppTooManyOptions;

##! #[ignore(item)]

use strict;
use warnings;

use Moose;
extends 'Perl::Gib::Exception';

sub _build_message {
    my $self = shift;

    return 'Too many options';
}

__PACKAGE__->meta->make_immutable;

1;
