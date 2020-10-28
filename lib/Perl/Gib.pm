package Perl::Gib;

##! Generate Perl project HTML documentation and run module test scripts.
##!
##!     use Perl::Gib;
##!     my $perlgib = Perl::Gib->new();
##!     $perlgib->doc();

use strict;
use warnings;

use feature qw(state);

use Moose;
use MooseX::Types::Path::Tiny qw(AbsPath AbsDir);

use Carp qw(croak carp);
use English qw(-no_match_vars);
use File::Copy::Recursive qw(dircopy dirmove);
use File::Find qw(find);
use Mojo::Template;
use Path::Tiny;
use Try::Tiny;

use Perl::Gib::Markdown;
use Perl::Gib::Module;
use Perl::Gib::Template;
use Perl::Gib::Index;

our $VERSION = '1.00';

no warnings "uninitialized";

### #[ignore(item)]
### List of processed Perl modules.
has 'modules' => (
    is      => 'ro',
    isa     => 'ArrayRef[Perl::Gib::Module]',
    lazy    => 1,
    builder => '_build_modules',
    init_arg => undef,
);

### #[ignore(item)]
### List of processed Markdown files.
has 'markdowns' => (
    is      => 'ro',
    isa     => 'ArrayRef[Perl::Gib::Markdown]',
    lazy    => 1,
    builder => '_build_markdowns',
    init_arg => undef,
);

### Path to directory with Perl modules and Markdown files. [optional]
### > Default `lib` in current directory.
has 'library_path' => (
    is      => 'ro',
    isa     => AbsDir,
    coerce  => 1,
    default => sub { path('lib')->absolute->realpath; },
);

### Output path for documentation. [optional]
### > Default `doc` in current directory.
has 'output_path' => (
    is      => 'ro',
    isa     => AbsPath,
    coerce  => 1,
    default => sub { path('doc')->absolute; },
);

### Document private items. [optional]
has 'document_private_items' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { 0 },
);

### Library name, used as index header. [optional]
### > Default `Library.`
has 'library_name' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { 'Library' },
);

### Prevent creating html index. [optional]
has 'no_html_index' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { 0 },
);

### #[ignore(item)]
### Working path (temporary directory) for HTML, Markdown files output.
has 'working_path' => (
    is       => 'ro',
    isa      => AbsPath,
    lazy     => 1,
    builder  => '_build_working_path',
    init_arg => undef,
);

### Document ignored items. [optional]
has 'document_ignored_items' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { 0 },
);

### Find Perl modules in given library path and process them. By default
### modules with pseudo function `#[ignore(item)]` in package comment block
### are ignored.
sub _build_modules {
    my $self = shift;

    my @files;
    find( sub { push @files, $File::Find::name if ( -f and /\.pm$/ ); },
        $self->library_path );

    my @modules;
    foreach my $file (@files) {
        my $module = try {
            Perl::Gib::Module->new(
                file                   => $file,
                document_private_items => $self->document_private_items,
                document_ignored_items => $self->document_ignored_items,
            )
        };
        next if ( !$module );
        push @modules, $module;
    }

    return \@modules;
}

### Find Markdown files in given library path and process them.
sub _build_markdowns {
    my $self = shift;

    my @files;
    find( sub { push @files, $File::Find::name if ( -f and /\.md$/ ); },
        $self->library_path );

    my @documents =
      map { Perl::Gib::Markdown->new( file => $_ ) } @files;

    return \@documents;
}

### Create temporary working directory.
sub _build_working_path {
    my $self = shift;

    return Path::Tiny->tempdir;
}

### Get path of resource element by label. If (relative) dir is provided the
### path will be returned relative otherwise absolute.
sub _get_resource_path {
    my ( $self, $label, $relative_dir ) = @_;

    state $determine = sub {
        my $file = path(__FILE__)->absolute->canonpath;
        my ($dir) = $file =~ /(.+)\.pm$/;

        return path( $dir, 'resources' );
    };
    state $path = &$determine();

    state %resources = (
        'lib:assets'           => path( $path, 'assets' ),
        'lib:templates'        => path( $path, 'templates' ),
        'lib:templates:object' => path( $path, 'templates', 'gib.html.ep' ),
        'lib:templates:index'  =>
          path( $path, 'templates', 'gib.index.html.ep' ),
        'out:assets'         => path( $self->working_path, 'assets' ),
        'out:index:html'     => path( $self->working_path, 'index.html' ),
        'out:index:markdown' => path( $self->working_path, 'index.md' ),
    );
    my $resource = $resources{$label};

    $resource = $resource->relative($relative_dir) if ($relative_dir);

    return $resource->canonpath;
}

### Get absolute output path (directory, file) of Perl::Gib object
### (Perl modules, Markdown files). The type identifies the output file suffix.
###
### * html => `.html`
### * markdown => `.md`
sub _get_output_path {
    my ( $self, $object, $type ) = @_;

    my $lib     = $self->library_path;
    my $working = $self->working_path;

    my $file = $object->file;
    $file =~ s/$lib/$working/;

    if ( $type eq 'html' ) {
        $file =~ s/\.pm|\.md$/\.html/;
    }
    elsif ( $type eq 'markdown' ) {
        $file =~ s/\.pm/\.md/;
    }

    return ( path($file)->parent->canonpath, $file );
}

### Create output directory, copy assets (CSS, JS, fonts), generate HTML
### content and write it to files.
###
### ```
###     use File::Find;
###     use Path::Tiny;
###
###     my $dir = Path::Tiny->tempdir->canonpath;
###
###     my $perlgib = Perl::Gib->new({output_path => $dir});
###     $perlgib->html();
###
###     my @wanted = (
###         path( $dir, "Perl/Gib.html" ),
###         path( $dir, "Perl/Gib/Markdown.html" ),
###         path( $dir, "Perl/Gib/Module.html" ),
###         path( $dir, "Perl/Gib/Template.html" ),
###         path( $dir, "Perl/Gib/Usage.html" ),
###         path( $dir, "index.html" ),
###     );
###
###     my @docs;
###     find( sub { push @docs, $File::Find::name if ( -f && /\.html$/ ); }, $dir );
###     @docs = sort @docs;
###
###     is_deeply( \@docs, \@wanted, 'all docs generated' );
### ```
sub html {
    my $self = shift;

    $self->working_path->mkpath;

    if ( !$self->no_html_index ) {

        my $index = Perl::Gib::Index->new(
            modules      => $self->modules,
            markdowns    => $self->markdowns,
            library_path => $self->library_path,
            library_name => $self->library_name,
        );

        my $template = $self->_get_resource_path('lib:templates:index');
        my $html     = Perl::Gib::Template->new(
            file    => $template,
            assets  => 'assets',
            content => $index,
        );

        $html->write( $self->_get_resource_path('out:index:html') );
    }

    foreach my $object ( @{ $self->modules }, @{ $self->markdowns } ) {
        my ( $dir, $file ) = $self->_get_output_path( $object, 'html' );
        path($dir)->mkpath;

        my $template = $self->_get_resource_path('lib:templates:object');
        my $html     = Perl::Gib::Template->new(
            file    => $template,
            assets  => $self->_get_resource_path( 'out:assets', $dir ),
            content => $object
        );

        $html->write($file);
    }

    dircopy(
        $self->_get_resource_path('lib:assets'),
        $self->_get_resource_path('out:assets')
    );
    dirmove( $self->working_path, $self->output_path );

    return;
}

### Run project modules test scripts.
sub test {
    my $self = shift;

    foreach my $module ( @{ $self->modules } ) {
        $module->run_test( $self->library_path );
    }

    return;
}

### Create output directory, generate Markdown content and write it to files.
### ```
###     use File::Find;
###     use Path::Tiny;
###
###     my $dir = Path::Tiny->tempdir->canonpath;
###
###     my $perlgib = Perl::Gib->new({output_path => $dir});
###     $perlgib->markdown();
###
###     my @wanted = (
###         path( $dir, "Perl/Gib.md" ),
###         path( $dir, "Perl/Gib/Markdown.md" ),
###         path( $dir, "Perl/Gib/Module.md" ),
###         path( $dir, "Perl/Gib/Template.md" ),
###         path( $dir, "Perl/Gib/Usage.md" ),
###     );
###
###     my @docs;
###     find( sub { push @docs, $File::Find::name if ( -f && /\.md$/ ); }, $dir );
###     @docs = sort @docs;
###
###     is_deeply( \@docs, \@wanted, 'all docs generated' );
### ```
sub markdown {
    my $self = shift;

    $self->working_path->mkpath;

    foreach my $object ( @{ $self->modules }, @{ $self->markdowns } ) {
        my ( $dir, $file ) = $self->_get_output_path( $object, 'markdown' );

        path($dir)->mkpath;
        path($file)->spew( $object->to_markdown() );
    }

    dirmove( $self->working_path, $self->output_path );

    return;
}

__PACKAGE__->meta->make_immutable;

1;
