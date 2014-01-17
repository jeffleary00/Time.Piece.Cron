#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Time::Piece::Cron' ) || print "Bail out!\n";
}

diag( "Testing Time::Piece::Cron $Time::Piece::Cron::VERSION, Perl $], $^X" );
