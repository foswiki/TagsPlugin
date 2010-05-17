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

use constant DEBUG => 0;    # toggle me

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

1;
