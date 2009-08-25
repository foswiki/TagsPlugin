# This script Copyright (c) 2009 Oliver Krueger, (wiki-one.net)
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

package Foswiki::Plugins::TagsPlugin::Rename;

use strict;
use warnings;
use Error qw(:try);

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::renameCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};

    my $tag_old = $query->param('oldtag') || '';
    my $tag_new = $query->param('newtag') || '';

    $tag_old = Foswiki::Sandbox::untaintUnchecked($tag_old);
    $tag_new = Foswiki::Sandbox::untaintUnchecked($tag_new);
    
    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $tag_old = Unicode::MapUTF8::from_utf8( { -string => $tag_old, -charset => $charset } );
    $tag_new = Unicode::MapUTF8::from_utf8( { -string => $tag_new, -charset => $charset } );
    

    #
    # checking prerequisites
    #

    # first check the existence of all necessary url parameters
    #
    if ( !$tag_old ) {
        $session->{response}->status(400);
        return "<h1>400 'oldtag' parameter missing</h1>";
    }
    if ( !$tag_new ) {
        $session->{response}->status(400);
        return "<h1>400 'newtag' parameter missing</h1>";
    }

    # check if current user is allowed to do so
    #
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup} || "AdminGroup";
    if ( !Foswiki::Func::isGroupMember( $tagAdminGroup, Foswiki::Func::getWikiName()) ) {
        $session->{response}->status(403);
        return "<h1>403 Forbidden</h1>";
    }
    
    #
    # actioning
    #
    $session->{response}->status(200);
    
    # returning the number of affected tags
    return Foswiki::Plugins::TagsPlugin::Rename::do( $tag_old, $tag_new );

}

=begin TML

---++ do( $tag_old, $tag_new )
This does untagging.

Takes the following parameters:
 tag_old : name of tag to be renamed
 tag_new : new name for the old tag

This routine does not check any prerequisites and/or priviledges. It returns 0, if
the old tagname was not found or the new tagname already exists.

Return:
 number of affected tags.
=cut

sub do {
    my ( $tag_old, $tag_new ) = @_;
    my $db = new Foswiki::Contrib::DbiContrib;

    # determine tag_id for given tag_old and exit if its not there
    #
    my $tag_id;
    my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    my $arrayRef = $db->dbSelect( $statement, $tag_old, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }
    else { return " 0"; }
    
    # check if new tagname already exists by probing for an tag_id
    #
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag_new, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        return " 0"; 
    }    

    # now we are ready to actually rename
    #
    $statement =
      sprintf( 'UPDATE %s SET %s = ? WHERE %s = ?',
        qw( Items item_name item_id ) );
    Foswiki::Func::writeDebug("Rename: $statement; ($tag_new, $tag_id)");
    my $affected_rows = $db->dbInsert( $statement, $tag_new, $tag_id );
    if ( $affected_rows eq "0E0" ) { $affected_rows=0; };
    
    # flushing data to dbms
    #    
    $db->commit();

    # add extra space, so that zero affected rows does not clash with returning "0" from rest invocation
    return " $affected_rows";
}

1;