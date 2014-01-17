#!/usr/bin/perl

use strict;
use warnings;
use Module::Build;


my $build = Module::Build->new
(
    module_name     => 'Time::Piece::Cron',
    license         => 'perl',
    dist_author     => 'Jeff Leary',
    requires        => {
              'perl'            => '5.8.4',
              'Time::Piece'     => '1.15',
              'Time::Seconds'   => undef,
              'Time::Local'     => '1.1900',
    },
);
$build->create_build_script;
