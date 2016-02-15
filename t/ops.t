use strict;
use warnings;
use Test::More;

use Scalar::Util qw( looks_like_number );
use Git::Version::Compare qw( :ops );

# pick up a random git version
my $version = shift @ARGV || join '.', int( 1 + rand 4 ), map int rand 13, 1 .. 2 + rand 2;
diag "fake git version $version";

# other versions based on the current one
my @version = split /\./, $version;
my ( @lesser, @greater );
for ( 0 .. $#version ) {
    local $" = '.';
    my @v = @version;
    next if !looks_like_number( $v[$_] );
    $v[$_]++;
    push @greater, "@v";
    next if 0 > ( $v[$_] -= 2 );
    push @lesser, "@v";
}

# more complex comparisons
my @true = (
    [ '1.7.2.rc0.13.gc9eaaa', 'eq_git', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'ge_git', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'le_git', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.1',                'gt_git', '1.7.1.rc0' ],
    [ '1.7.1.rc1',            'gt_git', '1.7.1.rc0' ],
    [ '1.3.2',                'gt_git', '0.99' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'gt_git', '1.7.0.4' ],
    [ '1.7.1.rc2',            'gt_git', '1.7.1.rc1' ],
    [ '1.7.2.rc0.1.g078e',    'gt_git', '1.7.2.rc0' ],
    [ '1.7.2.rc0.10.g1ba5c',  'gt_git', '1.7.2.rc0.1.g078e' ],
    [ '1.7.1.1',              'gt_git', '1.7.1.1.gc8c07' ],
    [ '1.7.1.1',              'gt_git', '1.7.1.1.g5f35a' ],
    [ '1.0.0b',               'gt_git', '1.0.0a' ],
    [ '1.0.3',                'gt_git', '1.0.0a' ],
    [ '1.7.0.4',              'ne_git', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.1.rc1',            'ne_git', '1.7.1.rc2' ],
    [ '1.0.0a',               'ne_git', '1.0.0' ],
    [ '1.4.0.rc1',            'le_git', '1.4.1' ],
    [ '1.0.0a',               'gt_git', '1.0.0' ],
    [ '1.0.0a',               'lt_git', '1.0.3' ],
    [ '1.0.0a',               'eq_git', '1.0.1' ],
    [ '1.0.0b',               'eq_git', '1.0.2' ],
    # the 0.99 series
    [ '0.99',                 'lt_git', '1.0.2' ],
    [ '0.99',                 'lt_git', '0.99.7a' ],
    [ '0.99.9c',              'lt_git', '0.99.9g' ],
    [ '0.99.7c',              'lt_git', '0.99.7d' ],
    [ '0.99.7c',              'lt_git', '0.99.8' ],
    [ '1.0.rc2',              'eq_git', '0.99.9i' ],
    # non-standard versions
    [ '1.7.1.236.g81fa0',     'gt_git', '1.7.1' ],
    [ '1.7.1.236.g81fa0',     'lt_git', '1.7.1.1' ],
    [ '1.7.1.211.g54fcb21',   'gt_git', '1.7.1.209.gd60ad81' ],
    [ '1.7.1.211.g54fcb21',   'ge_git', '1.7.1.209.gd60ad81' ],
    [ '1.7.1.209.gd60ad81',   'lt_git', '1.7.1.1.1.g66bd8ab' ],
    [ '1.7.0.2.msysgit.0',    'gt_git', '1.6.6' ],
    [ '1.7.1',                'lt_git', '1.7.1.1.gc8c07' ],
    [ '1.7.1',                'lt_git', '1.7.1.1.g5f35a' ],
    [ '1.7.1.1',              'gt_git', '1.7.1.1.gc8c07' ],
    [ '1.7.1.1',              'gt_git', '1.7.1.1.g5f35a' ],
    [ '1.7.1.1.gc8c07',       'eq_git', '1.7.1.1.g5f35a' ],
    [ '1.3.GIT',              'gt_git',  '1.3.0' ],
    [ '1.3.GIT',              'lt_git',  '1.3.1' ],
    [ '0.99.9l',              'eq_git',  '1.0rc4' ],
    # git tag names
    [ 'v1.7.1',               'lt_git', '1.7.1.1.g5f35a' ],
    [ '1.0.0a',               'ne_git', 'v1.0.0' ],
    [ 'v1.0.0b',              'eq_git', '1.0.2' ],
);

# operator reversal: $a op $b <=> $b rop $a
my %reverse = (
    eq_git => 'eq_git',
    ne_git => 'ne_git',
    ge_git => 'le_git',
    gt_git => 'lt_git',
    le_git => 'ge_git',
    lt_git => 'gt_git',
);
my %negate = (
    ne_git => 'eq_git',
    eq_git => 'ne_git',
    ge_git => 'lt_git',
    gt_git => 'le_git',
    le_git => 'gt_git',
    lt_git => 'ge_git',
);
@true = (
    @true,
    map { [ $_->[2], $reverse{ $_->[1] }, $_->[0], $_->[3] || () ] } @true
);

plan tests => 4 + 6 * @lesser + 6 * @greater + 2 * @true;

# eq_git
ok( eq_git($version, $version), "$version eq $version" );
ok( !eq_git($version, $_), "$version not eq $_" ) for @greater, @lesser;

# ne_git
ok( ne_git($version, $_), "$version ne $_" ) for @greater, @lesser;
ok( !ne_git($version, $version), "$version not ne $version" );

# gt_git
ok( gt_git($version, $_),  "$version gt $_" )     for @lesser;
ok( !gt_git($version, $_), "$version not gt $_" ) for @greater;

# le_git
ok( lt_git($version, $_),  "$version lt $_" )     for @greater;
ok( !lt_git($version, $_), "$version not lt $_" ) for @lesser;

# le_git
ok( le_git($version, $_), "$version le $_" ) for $version, @greater;
ok( !le_git($version, $_), "$version not le $_" ) for @lesser;

# ge_git
ok( ge_git($version, $_), "$version ge $_" ) for $version, @lesser;
ok( !ge_git($version, $_), "$version not ge $_" ) for @greater;

# test a number of special cases
my $dev;

for (@true) {
    ( $dev, my $op, my $v ) = @$_;
    no strict 'refs';
    ok( &$op($dev, $v), "$dev $op $v" );
    $op = $negate{$op};
    ok( !&$op($dev, $v), "$dev not $op $v" );
}

