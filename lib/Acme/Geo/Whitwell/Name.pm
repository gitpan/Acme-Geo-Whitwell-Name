package Acme::Geo::Whitwell::Name;

use strict;
use warnings;
use Carp qw(croak);

use Exporter;
@Acme::Geo::Whitwell::Name::ISA       = qw(Exporter);
@Acme::Geo::Whitwell::Name::EXPORT_OK = qw(to_whitwell from_whitwell);

use Scalar::Util qw(looks_like_number);

=head1 NAME

Acme::Geo::Whitwell::Name - Steadman Whitwell's "rational geographic nomenclature"

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use Acme::Geo::Whitwell::Name qw(to_whitwell from_whitwell);

    # Convert Sunnyvale, CA's lat and lon to a Whitwell name pair.
    my @names = to_whitwell("37.37N", "122.03");

    # Same conversion, using signed latitude and longitude instead.
    my @names = to_whitwell(37.37, -122.03);

    # Convert a Whitwell name to a latitude and longitude.
    # (Washington DC's "rational" name to N/S lat and E/W long.)
    my($lat_string, $lon_string) = from_whitwell("Feiro Nyvout");

    # If you want signed values, add signed => some true value.
    my($lat, $long) = from_whitwell("Feiro Nyvout", signed=>1);

=head1 DESCRIPTION

This module implements Steadman Whitwell's "rational system of geographic 
nomenclature", in which place names are generated by converting the latitude 
and longitude of the location into a two-part name by means of a 
transliteration scheme.

Whitwell devised this scheme in an attempt to provide an alternative to 
the proliferation of similarly-named towns in the early US. However, people
seemed to prefer creating many Springfields and Washingtons in preference to 
using Whitwell's uniquely quirky names. 

=head2 THE SCHEME

Two tables of number-to-letter(s) are used to translate latitudes and 
longitudes of two-decimal precision, digit-by-digit, into 
vaguely-pronounceable two-part names. 

             1 2 3 4 5 6 7  8  9  0
   latitude  a e i o u y ee ei ie ou  vowels
  longitude  b d f k l m n  p  r  t   consonants

Transliteration is done by looking up the apropriate digit in the tables above,
switching rows until all the digits are consumed. If the coordinate is negative,
a special 'sign consonant' is inserted into the (partial) name after the first 
vowel is added, and the transliteration continues by choosing again from the 
vowel table, then continuing to alternate again.

This is very orderly, but confusing to generate by hand (putting aside the 
fact that no one in their right mind really wants to live in "Isilu Buban"
instead of Sydney, AU, or "Feiro Nyvout" instead of Washington, DC). 

The generated names are guaranteed to have alternating consonants and vowels,
and should be pronounceable (though most likely bizarre). I have not been able
to locate the original documentation of the scheme, so I am unable to determine
why some example names are built in "reverse": with the first letter for the
latitude selected from the longitude table, and vice versa for the longitude. I
can only guess that the alternate construction was deemed more pronounceable or
"interesting". Since this is the case, I generate both alternatives so you can
choose the one that seems "better". In the cases of places like McMurdo Base
("Eeseepu Bymeem" or "Neeveil Amyny"), I'm not sure there I<is> a "better".

However, solely for the purposes of amusement, it can be interesting to find
out what a given location would have been called in tha alternate universe
where Whitwell's scheme caught on.

It would be lovely to use this module to change all the place names on 
online maps, wouldn't it?

=head2 SOURCES

=over

=item * I<The Angel and the Serpent: The Story of New Harmony>, William E.
Wilson, Indiana University Press, 1984, p. 154
=item * Search books.google.com for '"new harmony gazette" whitwell'
=item * http://www.kirchersociety.org/blog/2007/05/15/whitwells-system-for-a-rational-geographical-nomenclature/

=back

=cut

# These tables define the letters that the numbers will be transliterated into.
#                   0  1 2 3 4 5 6 7  8  9
my @vowels     = qw(ou a e i o u y ee ei ie); 
my @consonants = qw(t  b d f k l m n  p  r);

# Allows us to detect when to insert the "sign consonant" for negative 
# lats and lons.
my %vowel;
@vowel{@vowels} = (); 

=head1 EXPORT

=head1 FUNCTIONS

=head2 to_whitwell($lat, $lon)

Generates a properly-capitalized Whitwell name from a latitude-longitude pair.
Latitude and longitude are truncated to the two digits after the decimal point,
in keeping with Whitwell's original scheme. Zeroes are added after the decimal
point as necessary.

North latitudes are positve, and south latitudes are negative. East longitudes
are positive, west longitudes are negative. Trailing E/W and N/S are converted
into the appropriate sign. If you supply both for some reason, trailing 
sign indicators override signs.

Returns both alternatives for the name (see L<SCHEME>).

=cut

sub to_whitwell {
     my($lat, $lon) = @_;
     return ( _vowel_build($lat)     . ' ' . _consonant_build($lon),
              _consonant_build($lat) . ' ' . _vowel_build($lon)
     );
}

sub _vowel_build     { _gen(shift, [\@vowels, \@consonants], 's') }
sub _consonant_build { _gen(shift, [\@consonants, \@vowels], 'v') }

sub _gen {
    # The coordinate, the letter lists, and the appropriate sign consonant.
    my($coord, $lists, $neg) = @_;

    # Turn the floating-point number into a list of digits.
    # Note that _two_decimal does NOT CARE about sign or sign indicators.
    $coord = uc(my $orig_coord = $coord);
    my @coord = grep {/(\d)/} (split //, _two_decimal($coord));

    my $word = '';
    my $list = 0;
    my $signed = 0;

    my ($is_negative) = ($coord =~ s/[SW]//g);
    my ($is_positive) = ($coord =~ s/[NE]//g);

    croak 
        "Coordinate '$orig_coord' does not look like a proper coordinate"
            if !looks_like_number($coord);

    $is_negative = ($coord < 0) unless $is_negative;

    my $conflicting = ($is_negative and $is_positive) ? 'conflicting ' : '';
    croak "Multiple ${conflicting}sign indicators detected in '$orig_coord'"
      if  $conflicting or $is_negative > 1 or $is_positive > 1;

    foreach my $digit (@coord) {
        # Convert the next digit into a letter from the proper table.
        my $letter = $lists->[$list]->[$digit];
        ### "$letter -> $digit"

        # Decide whether to insert a sign consonant.        
        if (exists $vowel{$letter} and $is_negative and not $signed) {
            # If negative, we have a vowel, and we haven't inserted the sign
            # consonant yet, insert it.
            $letter .= $neg;
            # Now signed.
            $signed = 1;
            $list = !$list;
        }
        # Add new letter(s) to word and continue;
        $word .= $letter;
        $list = !$list;
    }
    return ucfirst $word;
}

sub _two_decimal {
    my ($coord) = @_;
    
    # Discard non-digits except for a decimal point.
    $coord =~ s/[^\d\.]//g;

    # Drop leading zeros.
    $coord =~ s/^0*//g;
    $coord = 0 unless $coord;

    if (abs($coord) > 180) {
        croak "$coord must be between -180 and +180\n";
    }
    unless ($coord =~ /\./) {
        # add decimals
        $coord .= ".";
    }
    # Add two more zeroes; we'll discard them if we don't need them.
    $coord .= "00"; 
    ($coord) = ($coord =~ /^(\d{0,3}\.\d\d)/);
    return $coord;
}

=head2 from_whitwell($whitwell_name, signed => $yes_or_no)

Converts a Whitwell name back into a lat/lon pair, in trailing indicator
format.  Results will be undefined if the string does not match the Whitwell
scheme; if the strings I<is> Whitwell-compatible, but includes extra letters,
these will be assumed to be further digits after the decimal point.

If you supply the 'signed' option with a true value, the returned values are
signed numbers rather than numbers with trailing sign indicators.

=cut

sub from_whitwell {
    my($name, %opts) = @_;
    my ($lat_name, $lon_name) = split(/\s+/, $name);

    my ($value, $negative);
    ($value, $negative) = _coord_for(lc($lat_name)); 
    if ($negative) {
        if ($opts{signed}) {
            $value = -$value;
        }
        else {
            $value .= "S";
        }
    }
    else {
        unless ($opts{signed}) {
            $value .= "N";
        }
    } 
    my $lat = $value;

    ($value, $negative) = _coord_for(lc($lon_name));
    if ($negative) {
        if ($opts{signed}) {
            $value = -$value;
        }
        else {
            $value .= "W";
        }
    }
    else {
        unless ($opts{signed}) {
            $value .= "E";
        }
    } 
    my $lon = $value;

    return ($lat, $lon);
    
}

sub _coord_for {
    my($original) = my($string) = @_;

    # Determine if the string starts in the vowel table or the consonant table.
    my @tables  = (\@consonants, \@vowels);
    my $vowel_found;
    my $current = ($string =~ /^[aeiouy]/) || 0;

    # Decompose and look up the character(s).
    my $coord_string;
    my $try_sign = 0;
    my $is_negative = 0;
    my $sign_checked = 0;

  PARSE:
    while ($string) {
        # If we need to look for the sign character, 
        # do so. Since we've allowed names to start in either table
        # as seems to have been the historical precedent (yes, someone
        # actually did use this at least once for a real placename),
        # we check for both sign characters and record whether or not
        # we found one.
        if ($try_sign) {
            # Don't try more than once.
            $try_sign = 0;
            if ($string =~ s/^[vs]//) {
                $is_negative = 1;
                # Return to the vowel table again.
                $current = 1;
                next PARSE;
            }
            # Note we've looked for the sign once, so we shouldn't look
            # again. This wil trap badly-placed sign characters.
            $sign_checked = 1; 
        }
        # Longer entries occur at the end of the vowel table, so
        # to avoid parsing 'ee' as 'e' and 'e', we try the longer
        # strings first. However: complicating this process is the '0'
        # entry, which is also a longer one, so it has to be checked first.
        for my $i (0, reverse 1..9) {
            my $char = $tables[$current]->[$i];
            if ($string =~ s/^$char//) {
                # Found it. Tack the number onto the coordinate string,
                # swap tables, and see if we need to check the sign.
                $coord_string .= $i;
                $try_sign = ($current == 1 and !$sign_checked);
                $current = !$current;
                next PARSE;
            }
        }
        # The current table should have matched, so the input string is bad.
        croak "Bad character or sequencing found in '$original' at '$string'";
    }
    # Insert the decimal point such that the resulting number is < 180.
    # This allows "high-precision" Whitwell names (constructed in some
    # manner other than via to_whitwell) to be converted back correctly.
    if (length($coord_string) >= 3) { 
        # Need to insert a decimal point. The final value must be < 180,
        # and we asssume at least two decimal places.

        # Let's try the easy case first, and insert a decimal point 
        # right before the last two digits. All names generated via 
        # to_whitwell() will work with this case. Since we know the 
        # coordinate string only has numbers in it, we can just divide
        # by 100.
        my $trial_value = $coord_string/100;

        # Manufactured by some other means. Move the decimal left one
        # character at a time until the number is < 180. We never do this
        # at all if our initial guess worked.
        $trial_value /= 10 while $trial_value > 180;
        $coord_string = $trial_value;
    }
    else {
        # < 3, so can't be > 180. Just add decimals.
        $coord_string .= ".00";
    }
    return ($coord_string, $is_negative);
}

=head1 AUTHOR

Joe McMahon, C<< <mcmahon at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-acme-geo-whitwell-name at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Acme-Geo-Whitwell-Name>.  I
will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head2 KNOWN BUGS

=over

=item * (0,0) isn't handled correctly; however, since there's nothing there
but water, this is not a practical limitation.

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Acme::Geo::Whitwell::Name


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Acme-Geo-Whitwell-Name>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Acme-Geo-Whitwell-Name>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Acme-Geo-Whitwell-Name>

=item * Search CPAN

L<http://search.cpan.org/dist/Acme-Geo-Whitwell-Name>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Joe McMahon, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Acme::Geo::Whitwell::Name
