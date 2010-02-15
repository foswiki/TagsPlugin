# This script Copyright (c) 2010 Oliver Krueger, (wiki-one.net)
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

package Foswiki::Plugins::TagsPlugin::Func;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ normalizeTagname( $tag_text )
Replaces <, >, ' and " with html entities.

=cut

sub normalizeTagname {
    my $tag_text = $_[0];

    # sanatize the tag_text
    # $tag_text =~ s/&/&amp;/g;
    $tag_text =~ s/</&#60;/g;
    $tag_text =~ s/>/&#62;/g;
    $tag_text =~ s/'/&#39;/g;
    $tag_text =~ s/"/&#34;/g;

    return $tag_text;
}

=begin TML

---++ getUserID( $user )
resolves the cuid for $user from the database

Returns:
  cuid value
=cut

sub getUserID {
    my $user = $_[0];
    my $user_id = Foswiki::Func::isGroup( $user ) ? $user : Foswiki::Func::getCanonicalUserID( $user );

    my $db = new Foswiki::Contrib::DbiContrib;

    my $cuid;
    my $statement =
      sprintf( 'SELECT %s from %s WHERE %s = ? ', qw( CUID Users FoswikicUID) );
    Foswiki::Func::writeDebug("TagsPlugin::Func::getUserID: $statement - $user_id") if DEBUG;
    my $arrayRef = $db->dbSelect( $statement, $user_id );
    if ( defined( $arrayRef->[0][0] ) ) {
        $cuid = $arrayRef->[0][0];
        Foswiki::Func::writeDebug("TagsPlugin::Func::getUserID: $cuid") if DEBUG;
    }

    return $cuid;
}

1;
