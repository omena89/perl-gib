# perlgib

**perlgib** is Perl's alternative documentation and test manager.

## Introduction

**perlgib** produces HTML documentation and runs tests from Perl code
comment lines.

## Installation

    $ perl Makefile.pl
    $ make dist
    $ VERSION=$(perl -Ilib -le 'require "./lib/Perl/Gib.pm"; print $Perl::Gib::VERSION')
    $ cpanm Perl-Gib-$VERSION.tar.gz

## Usage

Simply run `perlgib doc` - HTML files are placed in `doc` - or `perlgib test`
from within your Perl project. Beside Perl modules also Markdown files are
processed.

For the **Perl::Gib** API documentation run follwing command from within this
Perl distribution.

    $ perl bin/perlgib doc

### Items

**Perl::Gib** iterates through the `lib` directory and processes following
item documentation comment lines in the found Perl Modules.

* package (module) itself
* subroutines (methods)

If the postmodern object system for Perl 5
[Moose](https://metacpan.org/pod/Moose) is detected, following additional item
documentation comment lines are used.

* attributes `has`
* method modifiers `before`, `after`, `around`, `augment`, `override`.

### Comments

A **package** documentation comment line starts with two hashes followed by an
exclamation mark.

    ##! Package documentation comment line.

The documentation comment block must be placed after the namespace line.

    package Acme::Corporation;

    ##! The Acme Corporation is a fictional corporation that features
    ##! prominently in the Road Runner/Wile E. Coyote animated shorts as a
    ##! running gag featuring outlandish products that fail or backfire
    ##! catastrophically at the worst possible times.

A documentation comment line for all the other above listed Perl module items
starts with three hashes.

    ### Other item documentation line.

The documentation comment block must be placed before the item.

    ### Acme American wrought anvils.
    has 'anvils' => (
        is      => 'ro',
        isa     => 'Int',
        default => 10,
    );

    ### Hit an anvil.
    ###
    ### It rings like a bell.
    sub hit {
        my $self = shift;

        return "ring";
    }

### Tests

A documentation test block starts and ends with three apostrophe.

    ### ```

Test blocks must be placed in subroutine comment lines.

    ### Test the wrought anvil.
    ###
    ### ```
    ###     my $bell = hit();
    ###
    ###     is( $bell, "ring");
    ### ```
    sub hit {
        ...

The package itself and [Test::More](https://metacpan.org/pod/Test::More) are
included by default. The code is placed in a subtest named by the subroutine.
The final module test scipts are run by
[prove](https://metacpan.org/pod/distribution/Test-Harness/bin/prove).

### Exceptions

All *private* items - item name starting with an underscore - are ignored.
Items with a first documentation comment line contenting a *pseudo* method are
also ignored.

    ##! #[ignore(item)]

The whole package (module) is skipped.

    ### #[ignore(item)]

This ignores the followed item.

## Licenses

[The "Artistic License"](http://dev.perl.org/licenses/artistic.html).

Further licenses see `lib/Perl/Gib/resources/assets`

* `css/highlight.css`
* `css/normalize.css`
* `js/highlight.min.js`

