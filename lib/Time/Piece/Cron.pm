package Time::Piece::Cron;

use 5.006;
use strict;
use warnings;
use Carp;
use Time::Piece;
use Time::Seconds;
use Time::Local;

=head1 NAME

Time::Piece::Cron - Parse and evaluate times from crontab strings.

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Time::Piece;
    
    use Time::Piece::Cron;

    my $cron = Time::Piece::Cron->new();
    
    my $timepiece = $cron->next_time("30 08 * * Mon-Fri");
    
    my $time = $cron->next_timestamp("30 08 * * Mon-Fri");
    
    my $bool = $cron->is_now("*/15 * * * *");
    
    my $bool = $cron->parse_cron("30 08 * * Foo-Bar");

=head1 DESCRIPTION

Evaluate times from crontab type entries in a manner similar to the Vixie cron 
standards, and the guidelines found in the "man 5 crontab" documentation.

The cron time and date fields are:

field         allowed values
-----         --------------
minute        0-59
hour          0-23
day of month  1-31
month         1-12 (or names, see below)
day of week   0-7 (0 or 7 is Sun, or use names)

A field may be an asterisk (*), which always stands for "first-last".

Ranges of numbers are allowed.  Ranges are two numbers separated with a
hyphen.	The specified range is inclusive.  For example, 8-11 for an
"hours" entry specifies execution at hours 8, 9, 10 and 11.

Lists are allowed.  A list is a set of numbers (or ranges) separated by
commas.	Examples: "1,2,5,9", "0-4,8-12".

Step values can be used in conjunction with ranges.  Following a range
with "<number>" specifies skips of the number's value through the
range.  For example, "0-23/2" can be used in the hours field to specify
command	execution every other hour. Steps are also permitted after
an asterisk, so if you want to say "every two hours", just use "*/2".

Names can also be used for the "month" and "day of week" fields.  Use
the first three letters of the particular day or month (case doesn't matter).

Ranges and lists of names are allowed(**).
However, avoid Weekday and Month ranges that wrap from one week (or year) into 
the next, as this will result in unexpected behavior once the lists are 
expanded and sorted.
Such as:

  "30 08 * * Fri-Tue" or "30 08 * Dec-Mar *"

If you must span into another week or year, use absolute lists instead. 
Such as:

  "30 08 * * Fri,Sat,Sun,Mon,Tue" or "30 08 * Dec,Jan,Feb,Mar *"

Note: The day of a command's execution can be specified by two fields --
day of month, and day of week. If both fields are restricted (ie, aren't  *), 
the command will be run when either field matches the current time. 
For example,
"30 4 1,15 * 5" would cause a command to be run at 4:30 am on the 1st and 15th 
of each month, PLUS every Friday.
       
(**) = Deviates from Vixie cron standard.

=head1 METHODS

=head2 new

Create a new Time::Piece::Cron instance;

PARAMS

none
  
RETURNS

an object

    $cron = Time::Piece::Cron->new();

=cut

sub new
{
    my $class = shift;
    my $self = {
        cron_size => 5,
        ranges => [         [ 0,59 ],
                            [ 0,23 ],
                            [ 1,31 ],
                            [ 1,12 ],
                            [ 0,6 ]
                        ],
                        
        conversion => [     { 60 => 0 },
                            { 24 => 0 },
                            {},
                            {},
                            { 7 => 0}
                        ],
                        
        alphamap => [       {},
                            {},
                            {},
                            { qw(jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7
                                 aug 8 sep 9 oct 10 nov 11 dec 12) },
                            { qw(sun 0 mon 1 tue 2 wed 3 thu 4 fri 5 sat 6) }
                        ],
                        
        indexmap => {
                            0 => 'min',
                            1 => 'hour',
                            2 => 'mday',
                            3 => 'mon',
                            4 => '_wday'
                        },
                        
    };
    
    bless($self, $class);
    return $self;
}


=head2 is_now

Evaluate if a crontab string is true for the current time.

PARAMS

1. A string, like "05 * * * *"

2. Optionally, a Time::Piece object for a reference start time.

RETURNS

1 if TRUE

0 if FALSE

    $bool = $cron->is_now("30 08 * * Mon-Fri");

=cut

sub is_now
{
    my $self = shift;
    my $cron = shift;
    my $timepiece = shift;
    
    if (defined $timepiece) {
        # user passed a standard perl timestamp. wrong, but deal with it.
        if (ref($timepiece) ne "Time::Piece" and $timepiece =~ /\b\d+\d/) {
            $timepiece = Time::Piece->new($timepiece);        
        }
    }
    $timepiece = Time::Piece->new() if (! defined $timepiece); 
    
    
    my @atoms = $self->parse_cron($cron);
    my $mday = 0;
    
    return 0 if (! scalar(@atoms));
    
    foreach my $index (sort keys %{$self->{indexmap}}) {
        my $ref = $self->{indexmap}->{$index};
        my $possibles = $atoms[$index];
        my $found = 0;
        my $val = $timepiece->$ref;
        
        if ( grep(/\b$val\b/, @{$possibles} ) ) {
            $found = 1;
            $mday = 1 if ($index == 2);    
        }
        
        if ($index == 2) {
            # For some complex cases(like, "30 08 1 10 Tue"), a cron is valid
            # in TWO situations:
            #  - 08:30am on October 1st.
            #  - 08:30am on EVERY Tuesday in October.
            # So, do not be too hasty to abort if the MDAY field doesn't match,
            # because WDAY needs to be given opportunity to match in some cases
            next if (! $found and scalar(@{$atoms[4]}) < 7);
        }
        
        if ($index == 4) {
            return 1 if ($found); # wday was matched.
            return 1 if (! $found and $mday); # wday not match, but mday did.
        }
         
        return 0 if (! $found);
    }
       
    return 0;   
}


=head2 next_time

Returns a Time::Piece object representing the next time a cron entry will run.

If you just want to know if a cron entry will run right now, use instead the 
faster is_now() method.

PARAMS

1. A valid crontab string. like ("05 * * * *")

2. Optionally, a Time::Piece object for a reference start time.

RETURNS

A Time::Piece object

UNDEF on error.

    $timepiece = $cron->next_time("30 08 * * *");

=cut

sub next_time
{
    my $self = shift;
    my $cron = shift;
    my $master = shift;
    
    if (defined $master) {
        # user passed a standard perl timestamp. wrong, but deal with it.
        if (ref($master) ne "Time::Piece" and $master =~ /\b\d+\d/) {
            $master= Time::Piece->new($master);        
        }
    }
    $master = Time::Piece->new() if (! defined $master);
    
    
    my @atoms = $self->parse_cron($cron);
     return undef if (! scalar(@atoms));
    
    my @results; 
    my $mode = $self->_timesearch_mode(@atoms);
    my $pass = ($mode == 3) ? 2 : 1;
    my $timepiece;
    
    do {
        
        # create a copy of starting Time::Piece object and zero out the seconds.
        $timepiece = $master;
        $timepiece = Time::Piece->new( timelocal(0, @{$timepiece}[1 .. 5] ) );
        my $ymd_lock = 0;
        
        PARSEBLOCK:
        {    
            if ($timepiece->year > ($master->year + 1)) {
                carp "Cron parsing has gone out of range '$timepiece'";
                $timepiece = undef;
                last PARSEBLOCK;    
            }
            
            # iterate over cron sections in a specific order
            foreach my $index (3, 4, 2, 1, 0) {
                my $possibles = $atoms[$index];
                my $ref = $self->{indexmap}->{$index};
                my $max = ($self->{ranges}->[$index]->[-1] + 1) - $self->{ranges}->[$index]->[0];
                 
                # skip sections depending on allowed range, or mode/pass values
                next if (scalar(@{$possibles}) >= $max);
                next if ($index == 4 and $mode == 0);
                next if ($index == 4 and $pass == 2);
                next if ($index == 2 and $mode == 3 and $pass == 1);
                
                my $val = $self->_next_possible($timepiece->$ref, $possibles);
                
                if ($index == 2) {
                    # reset max to equal number of days in this month
                    $max = $self->_last_day_of_month($timepiece->_mon, $timepiece->_year);          
                }
                
                # mon parsing
                if ($index == 3) {
                    if ($val == $timepiece->$ref) {
                        next;
                    } elsif ($val > $timepiece->$ref) {
                        $timepiece += ONE_MONTH * ($val - $timepiece->$ref);    
                    } else {
                        $timepiece += ONE_MONTH * (($max - $timepiece->$ref) + $val);    
                    }
                    $timepiece = Time::Piece->new( timelocal(0,0,0,1,@{$timepiece}[4 .. 5]) );
                    
                # mday parsing    
                } elsif ($index == 2) {
                    if ($val == $timepiece->$ref) {
                        next;
                    } elsif ($val > $timepiece->$ref) {
                        # make sure we are not exceeding max number of days
                        # valid for this month.
                        if ($val > $max) { 
                            $timepiece += ONE_MONTH;
                            $timepiece = Time::Piece->new( timelocal(0,0,0,1,@{$timepiece}[4 .. 5]) );
                            redo PARSEBLOCK;  
                        } else {
                            $timepiece += ONE_DAY * ($val - $timepiece->$ref);
                        }    
                    } else {
                        $timepiece += ONE_DAY * (($max - $timepiece->$ref) + $val);
                        $timepiece = Time::Piece->new( timelocal(0,0,0,@{$timepiece}[3 .. 5]) );
                        redo PARSEBLOCK;    
                    }
                
                # hour parsing    
                } elsif ($index == 1) {
                    if ($val == $timepiece->$ref) {
                        next;
                    } elsif ($val > $timepiece->$ref) {
                        $timepiece += ONE_HOUR * ($val - $timepiece->$ref);
                        $timepiece = Time::Piece->new( timelocal(0,0,@{$timepiece}[2 .. 5]) );     
                    } else {
                        $timepiece += ONE_HOUR * (($max - $timepiece->$ref) + $val);
                        $timepiece = Time::Piece->new( timelocal(0,0,@{$timepiece}[2 .. 5]) );  
                        redo PARSEBLOCK;    
                    }
   
                # min parsing
                } elsif ($index == 0) {
                    if ($val == $timepiece->$ref) {
                        next;
                    } elsif ($val > $timepiece->$ref) {
                        $timepiece += ONE_MINUTE * ($val - $timepiece->$ref);
                        $timepiece = Time::Piece->new( timelocal(0,@{$timepiece}[1 .. 5]) );     
                    } else {
                        $timepiece += ONE_MINUTE * (($max - $timepiece->$ref) + $val);
                        $timepiece = Time::Piece->new( timelocal(0,@{$timepiece}[1 .. 5]) );  
                        redo PARSEBLOCK;    
                    }
                
                # the dreaded wday parsing!   
                } else {
                    if ($ymd_lock) {
			            # it is rare to end up in this loop a second time,
			            # but if it does happen... we have a bad DMY, and need
			            # to re-evaluate it from a later date.
                        $timepiece += ONE_DAY;
                    }
                    
                    my $temp = $self->_next_dow_time($val, $timepiece);
                                       
                    if ($temp->mon == $timepiece->mon) {
                        $timepiece = $temp;
                        $ymd_lock = 1;    
                    } else {
                        # next found day-of-week is beyond the range of the
                        # desired month. that won't do.
                        $timepiece += ONE_MONTH;
                        $timepiece = Time::Piece->new( timelocal(0,0,0,1,@{$timepiece}[4 .. 5]) );
                        $ymd_lock = 0;
                        redo PARSEBLOCK;   
                    }
                }
            }                 
        }
        
        push(@results, $timepiece) if (defined $timepiece);
        $pass --;
        
    } while ($pass);
    
    # nothing was found? shouldn't happen, but you never know...
    if (! scalar(@results)) {
        carp "Unable to calculate next_time for '$cron'";
        return undef;    
    }
    
    # if more than one result, return the earlier time
    if (scalar(@results) == 2) {
        if ($results[1]->epoch < $results[0]->epoch) {
            return $results[1];
        }
    }
    return $results[0];    
}


=head2 next_timestamp

Same as next_time(), but returns a regular perl timestamp (seconds since epoch)
instead of a Time::Piece object.

PARAMS

1. A valid crontab string. like ("05 * * * *")

2. Optionally, a perl timestamp for a reference start time.


RETURNS

A perl timestamp

UNDEF on error.

    $time = $cron->next_timestamp("30 08 * * *");

=cut

sub next_timestamp
{
    my $self = shift;
    my $cron = shift;
    my $time = shift || time();

    my $timepiece = Time::Piece->new($time);
    $timepiece = $self->next_time($cron, $timepiece);

    return timelocal(@{$timepiece});
}


=head2 parse_cron

Parse a crontab time string, and test for validity.
This method is mainly used internally, but may prove useful for other things.

PARAMS
  
A string, like "00,30 08 * * Mon-Fri"

RETURNS

In SCALAR context, returns whether or not it is a valid cron string.

1 if TRUE 
0 if FALSE

In ARRAY context, returns an array of the possible values for each segment.

ARRAY on success ([min 0-59],[hour 0-23],[mday 1-31],[mon 0-11],[wday 0-6])
UNDEF on Error


    $bool = $cron->parse_cron("30 08 * * Mon-Fri");

    @atoms = $cron->parse_cron("30 08 * * Mon-Fri");

=cut

sub parse_cron
{
    my $self = shift;
    my $cron = shift;
    my @results;
    
    if (! defined $cron or $cron eq "") {
        carp "Must provide valid cron string";
        return () if wantarray;
        return 0;      
    }
    
    my @segments = split(/\s+/, $cron);
    
    if (scalar(@segments) != $self->{cron_size}) {
        carp "Invalid number of elements in cron entry '$cron'";
        return () if wantarray;
        return 0;    
    }
    
    # decode and expand each segment into its range of valid numbers
    for (my $index = 0; $index < scalar(@segments); $index ++) {
        my @ary = $self->_expand_cron_index($segments[$index], $index);
        
        if (! scalar(@ary)) {
            carp "Cron index $index resulted in no values.";
            return () if wantarray;
            return 0;    
        }
        
        if ( grep(/\D/, @ary) ) {
            carp "Cron index $index contains invalid characters.";
            return () if wantarray;
            return 0;           
        }
        
        push(@results, \@ary);
    }
    
    return @results if wantarray;
    return 1;
}


# private method #
##################
# _last_day_of_month
#
#   Returns the last day number of a given month.
#
# PARAMS
#   A month number (localtime compliant 0 - 11)
#   A year number (localtime compliant -1900)
#
# RETURNS
#   a number (28 thru 31)
#
sub _last_day_of_month
{
    my $self = shift;
    my $mon = shift;
    my $year = shift;
    
    my $day;
    my $t = Time::Piece->new ( timelocal(0,0,0,28,$mon,$year) );
    
    while ($t->_mon == $mon) {
        $day = $t->mday;
        $t += ONE_DAY;    
    }
   
    return $day;  
} 


# private method #
##################
# _expand_cron_index()
#
# Parse a segment of a cron string. Convert all wildcards, ranges, etc., to
# a list of valid numbers.
#
# PARAMS:
#  1. A segment of cron text
#  2. The index number of the sent piece
#
# RETURNS:
#  an array of numbers
#
sub _expand_cron_index
{
    my $self = shift;
    my $cron = shift;
    my $index = shift;
    
    my @results;
    
    foreach my $piece ( split(/,/, $cron) ) {
        my $step = 0;
        my @atoms;
            
        # capture any defined steps (i.e., "*/15"), then remove.
        if ($piece =~ /\/(\d+)$/) {
            $step = $1;
            $piece =~ s/\/\d+$//;
        }
        
        # replace any text values with corresponding numbers.
        if (defined $self->{alphamap}->[$index]) {
            foreach my $key ( keys %{$self->{alphamap}->[$index]} ) {
                my $replacement = $self->{alphamap}->[$index]->{$key}; 
                next unless ($piece =~ /$key/i);
                $piece =~ s/$key/$replacement/ig;
            }
        }
        
        # fix common out-of-range numbers
        if (defined $self->{conversion}->[$index]) {
            foreach my $num ( keys %{$self->{conversion}->[$index]} ) {
                my $replacement = $self->{conversion}->[$index]->{$num};
                $piece =~ s/\b$num\b/$replacement/g;
            }
        }
        
        # a simple, singular number?
        if ($piece =~ /^\d+$/) {
            push(@results, $piece);
            next;
        }
        
        # expand asterisks into a range of numbers
        if ($piece =~ /\*/) {
            my $replacement = join('-', @{$self->{ranges}->[$index]});
            $piece =~ s/\*/$replacement/;
        }
        
        # expand ranges and place into @atoms
        if ($piece =~ /(\d+)-(\d+)/) {
            push(@atoms, ($1 .. $2));
        }
        
        # filter steps, or push all numbers into @range
        if ($step) {
            for (my $i = 0; $i < scalar(@atoms); $i++) {
                # the first value in an step range always gets added,
                # and so do numbers that divide evenly by the step.
                if ( $i == 0 or (! ($atoms[$i] % $step)) ) {
                    push(@results, $atoms[$i]);
                }
            }
        } else {
            push(@results, @atoms);
        }
    }
    
    # clean the array. remove duplicates, convert all to INT, sort numeric asc
    {
        my $max = $self->{ranges}->[$index]->[-1];
        my %hash = map { $_ => 1 } @results;
        @results = ();
        my @sorted = (sort {$a <=> $b} keys %hash);
        
        foreach my $val (@sorted) {
            if (int($val) <= $max) {
                push(@results, int($val));
            }
        }
    }
    
    return @results;
}


# private method #
##################
# _next_dow_time()
#
# Return Time::Piece object for the next occurence of the desired WDAY.
#
# PARAMS:
#  1. a DOW number.
#  2. A Time::Piece object representing a start time

# RETURNS:
#  A Time::Piece object 
#
sub _next_dow_time
{
    my $self = shift;
    my $dow = shift;
    my $tp = shift || Time::Piece->new();
    my $copy = $tp;
    my $tries = 7;
    
    while ($tries) {
        $copy = Time::Piece->new( timelocal(0,0,0,@{$copy}[3 .. 5]) );
        if ($copy->_wday == $dow) {
            return $copy;
        }
        $copy += ONE_DAY;
        $tries --;
    }
    carp "Unable to find next day-of-week";
    return undef;
}


# private method #
##################
# _timesearch_mode()
#
# Based on an expanded cron array, determine what mode of operation is needed.
#
#   mode 0: WDAY field is wide open, so only focus on MDAY and MON fields.
#   mode 1: WDAY field is limited, but MON and MDAY fields are wide open.
#   mode 2: WDAY and MON fields are both limited, but MDAY is wide open.
#   mode 3: WDAY, MON, and MDAY fields are all limited. This is the worst case.
# 
# PARAMS:
#  1. An expanded crontab array
#
# RETURNS:
#  a number (0-3)
#
sub _timesearch_mode
{
    my $self = shift;
    my @ary = @_;
    
    my $mode = 0;
    my $dmax = ($self->{ranges}->[2]->[-1] + 1)- $self->{ranges}->[2]->[0];
    my $mmax = ($self->{ranges}->[3]->[-1] + 1)- $self->{ranges}->[3]->[0];
    my $wmax = ($self->{ranges}->[4]->[-1] + 1) - $self->{ranges}->[4]->[0];
    
    if ($wmax == scalar(@{$ary[4]})) {
        $mode = 0;
    } elsif (   $wmax != scalar(@{$ary[4]}) and 
                $mmax != scalar(@{$ary[3]}) and 
                $dmax != scalar(@{$ary[3]}) ) {
        $mode = 3;
    } elsif (   $wmax != scalar(@{$ary[4]}) and 
                $mmax != scalar(@{$ary[3]}) ) {
        $mode = 2;
    } else {
        $mode = 1;
    }

    return $mode;
}


# private method #
##################
# _next_possible()
#
# Select the next higher (or same) value from an array, based on a
# starting number.
# If no suitable value found, selects the first lower value.
#
# PARAMS:
#  1. A starting number.
#  2. An array-reference to an array of numbers.
#
# RETURNS:
#  a number
#
sub _next_possible
{
    my $self = shift;
    my $number = shift;
    my $aref = shift;
     
    foreach my $i (@{$aref}) {
        return $i if ($i >= $number);
    }
    
    # couldn't find same or higher, so return lowest possible
    return $aref->[0];
}


=head1 AUTHOR

Jeffrey Leary, C<< <jeff at sillymonkeysoftware.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-time-piece-cron at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Time-Piece-Cron>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 TO DO

Add a last_time() method.

Test harness is very rudimentary. Could use better tests.

Possibly add ability to handle special characters (L, W, ?, \#) found in some
non-standard implementations of cron.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Time::Piece::Cron


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Time-Piece-Cron>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Time-Piece-Cron>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Time-Piece-Cron>

=item * Search CPAN

L<http://search.cpan.org/dist/Time-Piece-Cron/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 SEE ALSO

Time::Piece
L<http://perldoc.perl.org/Time/Piece.html>

Cron
L<http://wikipedia.org/wiki/Cron>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Jeffrey Leary.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Time::Piece::Cron
