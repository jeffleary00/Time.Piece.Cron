#!/usr/bin/env perl

# test the basic functionality of the Time::Piece::Cron module

use strict;

use Test::More tests => 5;


## BEGIN ##

use_ok('Time::Piece');
use_ok('Time::Piece::Cron');


# a timepiece for testing. Set seconds to 0.
my $timepiece = Time::Piece->new();
 
my $obj = Time::Piece::Cron->new();

ok( defined($obj),                                                  'new()' );

ok( $obj->parse_cron("30 08 * * *"),                         'parse_cron()' );

ok( $obj->is_now("* * * * *"),                                   'is_now()' );



