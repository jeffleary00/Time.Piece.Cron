#!/usr/bin/env perl

# test the basic functionality of the Time::Piece::Cron module

use strict;

use Test::More tests => 10;


## BEGIN ##

use_ok('Time::Piece');
use_ok('Time::Seconds');
use_ok('Time::Local');
use_ok('Time::Piece::Cron');


# a timepiece for testing. Set seconds to 0.
my $timepeice = Time::Piece->new();
$timepiece = Time::Piece->new( timelocal(0, @{$timepiece}[1 .. 5]) );
 
my $obj = Time::Cron->new();

ok( defined($obj),                                                  'new()' );

ok( $obj->parse_cron("30 08 * * *"),                         'parse_cron()' );

ok( scalar(@{$obj->parse_cron("30 08 * * *")}) == 5,         'parse_cron()' );

ok( $obj->is_now("* * * * *"),                                   'is_now()' );

# test a time that we KNOW will fail (previous minute).
ok( ! $obj->is_now("$atoms[1] * * * *", $time - 60),           'is_now(no)' );

# test the next_time to ensure it returns same as time()
ok( $obj->next_time("* * * * *", $time) == $time,             'next_time()' );


