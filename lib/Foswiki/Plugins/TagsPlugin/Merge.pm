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

package Foswiki::Plugins::TagsPlugin::Merge;

use strict;
use warnings;
use Error qw(:try);

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::mergeCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};

    my $tag1 = $query->param('tag1') || '';
    my $tag2 = $query->param('tag2') || '';

    $tag1 = Foswiki::Sandbox::untaintUnchecked($tag1);
    $tag2 = Foswiki::Sandbox::untaintUnchecked($tag2);
    
    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $tag1 = Unicode::MapUTF8::from_utf8( { -string => $tag1, -charset => $charset } );
    $tag2 = Unicode::MapUTF8::from_utf8( { -string => $tag2, -charset => $charset } );
    

    #
    # checking prerequisites
    #

    # first check the existence of all necessary url parameters
    #
    if ( !$tag1 ) {
        $session->{response}->status(400);
        return "<h1>400 'tag1' parameter missing</h1>";
    }
    if ( !$tag2 ) {
        $session->{response}->status(400);
        return "<h1>400 'tag2' parameter missing</h1>";
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
    
    # returning 0 on failure and some other positive number on success
    return Foswiki::Plugins::TagsPlugin::Merge::do( $tag1, $tag2 );

}

=begin TML

---++ do( $tag1, $tag2 )
This does the merging. Updates both Stat tables and deletes unused entries for obsolete tag2.

Takes the following parameters:
 tag1 : name of the tag which remains
 tag2 : name of the tag which will be merged into tag1

This routine does not check any prerequisites and/or priviledges. It returns 0, if
tag1 or tag2 was not found.

Return:
 0 on failure, any other positive number on success.
=cut

sub do {
    my ( $tag1, $tag2 ) = @_;
    my $db = new Foswiki::Contrib::DbiContrib;

    # determine tag_id for given tag1 and exit if its not there
    #
    my $tag_id1;
    my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    my $arrayRef = $db->dbSelect( $statement, $tag1, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id1 = $arrayRef->[0][0];
    }
    else { return " 0"; }

    # determine tag_id for given tag2 and exit if its not there
    #
    my $tag_id2;
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag2, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id2 = $arrayRef->[0][0];
    }
    else { return " 0"; }
    
    # now we are ready to actually merge
    #
    
    # merge the usage of the tags (in UserItemTag)
    # IGNOREing duplicate entries, which usually occur (may leave some garbage behind)
    $statement =
      sprintf( 'UPDATE IGNORE %s SET %s = ? WHERE %s = ?',
        qw( UserItemTag tag_id tag_id ) );
    my $affected_rows = $db->dbInsert( $statement, $tag_id1, $tag_id2 );
    Foswiki::Func::writeDebug("Merge: $statement; ($tag_id1, $tag_id2) -> $affected_rows");
    if ( $affected_rows eq "0E0" ) { $affected_rows=0; };
    # DELETEing the garbage (usually tags on topics, which were tagged with tag1 and tag2)
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( UserItemTag tag_id) );
    my $modified = $db->dbDelete( $statement, $tag_id2 );        
    Foswiki::Func::writeDebug("Merge: $statement; ($tag_id2) -> $modified");    
    
    # update stats in TagStat (rebuild it actually)
    my $tagstat = 0;
    $statement = sprintf( 'SELECT count(*) as count from %s WHERE %s = ?',
        qw( UserItemTag tag_id ) );
    $arrayRef = $db->dbSelect( $statement, $tag_id1 );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tagstat = $arrayRef->[0][0];
    }
    $statement =
      sprintf( 'UPDATE %s SET %s=? WHERE %s = ?',
        qw( TagStat num_items tag_id) );
    $modified = $db->dbInsert( $statement, $tagstat, $tag_id1 );
    Foswiki::Func::writeDebug("Merge: $statement; ($tagstat, $tag_id1) -> $modified");        
    unless ( $modified ) {
        $statement =
          sprintf( 'INSERT INTO %s (%s, %s) VALUES (?, ?)',
            qw( TagStat tag_id num_items ) );
        $modified = $db->dbInsert( $statement, $tag_id1, $tagstat );
        Foswiki::Func::writeDebug("Merge: $statement; ($tag_id1, $tagstat) -> $modified");        
    }
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( TagStat tag_id) );
    $modified = $db->dbDelete( $statement, $tag_id2 );        
    Foswiki::Func::writeDebug("Merge: $statement; ($tag_id2) -> $modified");    
    
    # update stats in UserTagStat    
    ### TODO: implement rebuilding UserTagStat rebuild

    # delete (empty) tag2
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( Items item_id) );
    $modified = $db->dbDelete( $statement, $tag_id2 );        
    Foswiki::Func::writeDebug("Merge: $statement; ($tag_id2) -> $modified");    
    
    # flushing data to dbms
    #    
    $db->commit();

    # add extra space, so that zero affected rows does not clash with returning "0" from rest invocation
    return " $affected_rows";
}

1;