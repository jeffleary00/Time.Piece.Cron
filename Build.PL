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
              'Time::Piece'     => '1.22',
              'Time::Seconds'   => '1.17',
              'Time::Local'     => '1.2100',
    },
);
$build->create_build_script;
