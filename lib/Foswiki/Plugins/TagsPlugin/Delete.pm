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

package Foswiki::Plugins::TagsPlugin::Delete;

use strict;
use warnings;
use Error qw(:try);

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::deleteCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};    

    my $tag_text   = $query->param('tag')         || '';
    my $redirectto = $query->param('redirectto')  || '';    
    $tag_text   = Foswiki::Sandbox::untaintUnchecked($tag_text);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);    
    
    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $tag_text   = Unicode::MapUTF8::from_utf8( { -string => $tag_text,   -charset => $charset } );
    $redirectto = Unicode::MapUTF8::from_utf8( { -string => $redirectto, -charset => $charset } );    
    

    #
    # checking prerequisites
    #

    # first check the existence of all necessary url parameters
    #
    if ( !$tag_text ) {
        $session->{response}->status(400);
        return "<h1>400 'tag' parameter missing</h1>";
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
    my $retval = Foswiki::Plugins::TagsPlugin::Delete::do( $tag_text );
    
    # redirect on request
    if ( $redirectto ) {
        Foswiki::Func::redirectCgiQuery( undef, $redirectto );
    }    
    
    return $retval;
}

=begin TML

---++ do( $tag_text )
This does the delete including all (user) instances of the tag.

Takes the following parameters:
 tag_text  : name of the tag

This routine does not check any prerequisites and/or priviledges. It returns 0, if
the given tag_text was not found.

Return:
 number of affected tags in the format "n+m" with n as the number of tags and m as the number of (user) tag instances.
=cut

sub do {
    my ( $tag_text ) = @_;
    my $db = new Foswiki::Contrib::DbiContrib;
    my $retval = "";

    # determine tag_id for given tag_text and exit if its not there
    #
    my $tag_id;
    my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    my $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }
    else { return 0; }

    # now we are ready to actually delete
    #
    # delete tag instances first
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( UserItemTag tag_id ) );
    my $affected_rows = $db->dbDelete( $statement, $tag_id );
    if ( $affected_rows eq "0E0" ) { $affected_rows=0; };
    $retval = "$affected_rows";

    # then delete the tag itself
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( Items item_id ) );
    $affected_rows = $db->dbDelete( $statement, $tag_id );
    if ( $affected_rows eq "0E0" ) { $affected_rows=0; };
    $retval = "$affected_rows+$retval";
        
    # update statistics
    #
    # ...in UserTagStat
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( UserTagStat tag_id ) );
    $affected_rows = $db->dbDelete( $statement, $tag_id );
    # ...in TagStat
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ?',
        qw( TagStat item_id ) );
    $affected_rows = $db->dbDelete( $statement, $tag_id );    

    # flushing data to dbms
    #    
    $db->commit();

    return $retval;
}

1;