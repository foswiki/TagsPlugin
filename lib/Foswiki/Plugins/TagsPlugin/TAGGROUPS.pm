# This script Copyright 
# (c) 2009 Oliver Krueger, (wiki-one.net)
# and distributed under the GPL (see below)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# Author(s): Oliver Krueger

package Foswiki::Plugins::TagsPlugin::TAGGROUPS;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ do( $session, $params, $topic, $web )
Taghandler for TAGGROUPS.

Return:
 Formatted list of current users groups.
=cut

sub do {
    my ( $session, $params, $topic, $web ) = @_;

    my $theHeader = $params->{header}    || '';
    my $theSep    = $params->{separator} || $params->{sep} || ',';
    my $theFooter = $params->{footer}    || '';
    my $theFormat = $params->{format}    || '$group';
    
    my $output = '';
    my @groups = ();

    # get the groups and rotate through it 
    my $it = Foswiki::Func::eachGroup();
    while ($it->hasNext()) {
        my $group = $it->next();
        if ( !Foswiki::Func::isGroupMember( $group ) ) { next; };
        my $entry = $theFormat;

        $entry =~ s/\$group/$group/g;
        
        # insert seperator only if needed
        if ( $output ne '' ) {
            $output .= $theSep . $entry;
        } else {
            $output = $entry;
        }
    }

    $output = $theHeader . $output . $theFooter if ($output);

    # expand standard escapes
    $output =~ s/\$n/\n/g;
    $output =~ s/\$percnt/\%/g;
    $output =~ s/\$quot/"/g;
    $output =~ s/\$dollar/\$/g;

    return $output;
}

1;
