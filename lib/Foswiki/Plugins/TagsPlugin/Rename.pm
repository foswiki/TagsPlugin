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

use constant DEBUG => 0; # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::renameCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};

    my $tag_old    = $query->param('oldtag')     || '';
    my $tag_new    = $query->param('newtag')     || '';
    my $redirectto = $query->param('redirectto') || '';    

    $tag_old    = Foswiki::Sandbox::untaintUnchecked($tag_old);
    $tag_new    = Foswiki::Sandbox::untaintUnchecked($tag_new);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);    
    
    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $tag_old    = Unicode::MapUTF8::from_utf8( { -string => $tag_old,    -charset => $charset } );
    $tag_new    = Unicode::MapUTF8::from_utf8( { -string => $tag_new,    -charset => $charset } );
    $redirectto = Unicode::MapUTF8::from_utf8( { -string => $redirectto, -charset => $charset } );    
    

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
    my $retval;
    try {
      $retval = Foswiki::Plugins::TagsPlugin::Rename::do( $tag_old, $tag_new );
    } catch Error::Simple with {
      my $e = shift;
      my $n = $e->{'-value'};
      if ( $n == 1 ) {
        $session->{response}->status(404);
        return "<h1>404 " . $e->{'-text'} . "</h1>";
      } elsif ( $n == 2 ) {
        $session->{response}->status(409);
        return "<h1>409 " . $e->{'-text'} . "</h1>";
      } elsif ( $n == 3 ) {
        $session->{response}->status(500);
        return "<h1>500 " . $e->{'-text'} . "</h1>";
      } else {
        $e->throw();
      }
    };
    
    # redirect on request
    if ( $redirectto ) {
        Foswiki::Func::redirectCgiQuery( undef, $redirectto );
    }
        
    return $retval; 
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
    } else { 
        throw Error::Simple("Database error: tag_old not found.", 1);
    }
    
    # check if new tagname already exists by probing for an tag_id
    #
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag_new, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        throw Error::Simple("Database error: tag_new already exists.", 2);
    }    

    # now we are ready to actually rename
    #
    $statement =
      sprintf( 'UPDATE %s SET %s = ? WHERE %s = ?',
        qw( Items item_name item_id ) );
    Foswiki::Func::writeDebug("Rename: $statement; ($tag_new, $tag_id)") if DEBUG;
    my $affected_rows = $db->dbInsert( $statement, $tag_new, $tag_id );
    if ( $affected_rows eq "0E0" ) { 
      throw Error::Simple("Database error: failed to rename the tag.", 3);
    };
    
    # flushing data to dbms
    #    
    $db->commit();

    # add extra space, so that zero affected rows does not clash with returning "0" from rest invocation
    return " $affected_rows";
}

1;
