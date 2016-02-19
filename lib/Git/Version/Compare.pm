package Git::Version::Compare;

use strict;
use warnings;
use Exporter;

use Scalar::Util qw( looks_like_number );
use namespace::clean;

my @ops = qw( lt gt le ge eq ne );

our @ISA         = qw(Exporter);
our @EXPORT_OK   = ( map "${_}_git", cmp => @ops );
our %EXPORT_TAGS = ( ops => [ map "${_}_git", @ops ], all => \@EXPORT_OK );

# A few versions have two tags, or non-standard numbering:
# - the left-hand side is what `git --version` reports
# - the right-hand side is an internal canonical name
#
# We turn versions into strings, so we can use the fast `eq` and `gt`.
# The 6 elements are integers padded with 0:
# - the 4 parts of the dotted version (padded with as many .0 as needed)
# - '.000' if not an RC, or '-xxx' if an RC (- sorts before . in ascii)
# - the number of commits since the previous tag (for dev versions)
#
# The special cases are pre-computed below, the rest is computed as needed.
my %version_alias = (
    '0.99.7a' => '000.099.007.001.000.000',
    '0.99.7b' => '000.099.007.002.000.000',
    '0.99.7c' => '000.099.007.003.000.000',
    '0.99.7d' => '000.099.007.004.000.000',
    '0.99.8a' => '000.099.008.001.000.000',
    '0.99.8b' => '000.099.008.002.000.000',
    '0.99.8c' => '000.099.008.003.000.000',
    '0.99.8d' => '000.099.008.004.000.000',
    '0.99.8e' => '000.099.008.005.000.000',
    '0.99.8f' => '000.099.008.006.000.000',
    '0.99.8g' => '000.099.008.007.000.000',
    '0.99.9a' => '000.099.009.001.000.000',
    '0.99.9b' => '000.099.009.002.000.000',
    '0.99.9c' => '000.099.009.003.000.000',
    '0.99.9d' => '000.099.009.004.000.000',
    '0.99.9e' => '000.099.009.005.000.000',
    '0.99.9f' => '000.099.009.006.000.000',
    '0.99.9g' => '000.099.009.007.000.000',
    '0.99.9h' => '000.099.009.008.000.000',    # 1.0.rc1
    '1.0.rc1' => '000.099.009.008.000.000',
    '0.99.9i' => '000.099.009.009.000.000',    # 1.0.rc2
    '1.0.rc2' => '000.099.009.009.000.000',
    '0.99.9j' => '000.099.009.010.000.000',    # 1.0.rc3
    '1.0.rc3' => '000.099.009.010.000.000',
    '0.99.9k' => '000.099.009.011.000.000',
    '0.99.9l' => '000.099.009.012.000.000',    # 1.0.rc4
    '1.0.rc4' => '000.099.009.012.000.000',
    '0.99.9m' => '000.099.009.013.000.000',    # 1.0.rc5
    '1.0.rc5' => '000.099.009.013.000.000',
    '0.99.9n' => '000.099.009.014.000.000',    # 1.0.rc6
    '1.0.rc6' => '000.099.009.014.000.000',
    '1.0.0a'  => '001.000.001.000.000.000',
    '1.0.0b'  => '001.000.002.000.000.000',
);

sub _normalize {
    my ($v) = @_;
    return undef if !defined $v;

    # reformat git.git tag names, output of `git --version`
    $v =~ s/^v|^git version |\.msysgit.*//g;
    $v =~ y/-/./;
    $v =~ s/0rc/0.rc/;
    return $version_alias{$v} if defined $version_alias{$v};

    my @v = split /\./, $v;
    my ( $r, $c ) = ( 0, 0 );

    # commit count since the previous tag
    ($c) = ( 1, splice @v, -1 ) if $v[-1] eq 'GIT';           # before 1.4
    ($c) = splice @v, -2 if substr( $v[-1], 0, 1 ) eq 'g';    # after  1.4

    # release candidate number
    ($r) = splice @v, -1 if substr( $v[-1], 0, 2 ) eq 'rc';
    $r &&= do { $r =~ s/rc//; sprintf '-%03d', $r };

    join( '.', map sprintf( '%03d', $_ ), ( @v, 0, 0, 0 )[ 0 .. 3 ] )
      . ( $r || '.000' )
      . sprintf( '.%03d', $c );
}

for my $op (@ops) {
    no strict 'refs';
    *{"${op}_git"} = eval << "OP";
    sub {
        my ( \$v1, \$v2 ) = \@_;
        \$_ = \$version_alias{\$_} ||= _normalize( \$_ ) for \$v1, \$v2;
        return \$v1 $op \$v2;
    }
OP
}

sub cmp_git ($$) {
    my ( $v1, $v2 ) = @_;
    $_ = $version_alias{$_} ||= _normalize( $_ ) for $v1, $v2;
    return $v1 cmp $v2;
}

1;

__END__

=head1 NAME

Git::Version::Compare - Functions to compare Git versions

=head1 SYNOPSIS

    use Git::Version::Compare qw( cmp_git );

    # result: 1.2.3 1.7.0.rc0 1.7.4.rc1 1.8.3.4 1.9.3 2.0.0.rc2 2.0.3 2.3.0.rc1
    my @versions = sort cmp_git qw(
      1.7.4.rc1 1.9.3 1.7.0.rc0 2.0.0.rc2 1.2.3 1.8.3.4 2.3.0.rc1 2.0.3
    );

=head1 DESCRIPTION

L<Git::Version::Compare> contains a selection of subroutines that make
dealing with Git-related things (like versions) a little bit easier.

The strings to compare can be version numbers, tags from C<git.git>
or the output of C<git version> or C<git describe>.

These routines collect the knowledge about Git versions that
was accumulated while developing L<Git::Repository>.

=head1 AVAILABLE FUNCTIONS

By default L<Git::Version::Compare> does not export any subroutines.

=head2 lt_git

    if ( lt_git( $v1, $v2 ) ) { ... }

A Git-aware version of the C<lt> operator.

=head2 gt_git

    if ( gt_git( $v1, $v2 ) ) { ... }

A Git-aware version of the C<gt> operator.

=head2 le_git

    if ( le_git( $v1, $v2 ) ) { ... }

A Git-aware version of the C<le> operator.

=head2 ge_git

    if ( ge_git( $v1, $v2 ) ) { ... }

A Git-aware version of the C<ge> operator.

=head2 eq_git

    if ( eq_git( $v1, $v2 ) ) { ... }

A Git-aware version of the C<eq> operator.

=head2 ne_git

    if ( ne_git( $v1, $v2 ) ) { ... }

A Git-aware version of the C<ne> operator.

=head2 cmp_git

    @versions = sort cmp_git @versions;

A Git-aware version of the C<cmp> operator.

=head1 EXPORT TAGS

=head2 :ops

Exports C<lt_git>, C<gt_git>, C<le_git>, C<ge_git>, C<eq_git>, and C<ne_git>.

=head2 :all

Exports C<lt_git>, C<gt_git>, C<le_git>, C<ge_git>, C<eq_git>, C<ne_git>,
and C<cmp_git>.

=head1 EVERYTHING YOU EVER WANTED TO KNOW ABOUT GIT VERSION NUMBERS

=head1 Version numbers

Version numbers as returned by C<git version> are in the following
formats (since the C<1.4> series, in 2006):

    # stable version
    1.6.0
    2.7.1

    # maintenance release
    1.8.5.6

    # release candidate
    1.6.0.rc2

    # development version
    # (the last two elements come from `git describe`)
    1.7.1.209.gd60ad
    1.8.5.1.21.gb2a0afd
    2.3.0.rc0.36.g63a0e83

In the C<git.git> repository, several commits have multiple tags
(e.g. C<v1.0.1> and C<v1.0.2> point respectively to C<v1.0.0a>
and C<v1.0.0b>). Pre-1.0.0 versions also have non-standard formats
like C<0.99.9j> or C<1.0rc2>.

This explains why:

    # this is true
    eq_git( '0.99.9l', '1.0rc4' );
    eq_git( '1.0.0a',  '1.0.1' );

    # this is false
    ge_git( '1.0rc3', '0.99.9m' );

C<git version> appeared in version C<1.3.0>.
C<git --version> appeared in version C<0.99.7>. Before that, there is no
way to know which version of Git one is dealing with.

C<Git::Version::Compare> converts all version numbers to an internal
format before performing a simple string comparison.

=head2 Development versions

Prior to C<1.4.0-rc1> (June 2006), compiling a development version of Git
would lead C<git --version> to output C<1.x-GIT> (with C<x> in C<0 .. 3>),
which would make comparing versions that are very close a futile exercise.

Other issues exist when comparing development version numbers with one
another. For example, C<1.7.1.1> is greater than both C<1.7.1.1.gc8c07>
and C<1.7.1.1.g5f35a>, and C<1.7.1> is less than both. Obviously,
C<1.7.1.1.gc8c07> will compare as greater than C<1.7.1.1.g5f35a>
(asciibetically), but in fact these two version numbers cannot be
compared, as they are two siblings children of the commit tagged
C<v1.7.1>). For practical purposes, the version-comparison methods
declares them equal.

Therefore:

    # this is true
    lt_git( '1.8.5.4.8.g7c9b668', '1.8.5.4.19.g5032098' );
    gt_git( '1.3.GIT', '1.3.0' );

    # this is false
    ne_git( '1.7.1.1.gc8c07', '1.7.1.1.g5f35a' );
    gt_git( '1.3.GIT', '1.3.1' );

If one were to compute the set of all possible version numbers (as returned
by C<git --version>) for all git versions that can be compiled from each
commit in the F<git.git> repository, the result would not be a totally ordered
set. Big deal.

Also, don't be too precise when requiring the minimum version of Git that
supported a given feature. The precise commit in git.git at which a given
feature was added doesn't mean as much as the release branch in which that
commit was merged.

=head1 SEE ALSO

L<Test::Requires::Git>, for defining Git version requirements in test
scripts that need B<git>.

=head1 COPYRIGHT

Copyright 2016 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
