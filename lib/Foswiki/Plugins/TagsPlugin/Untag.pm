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

package Foswiki::Plugins::TagsPlugin::Untag;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::untagCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};    

    my $item_name     = $query->param('item')        || '';
    my $tag_text      = $query->param('tag')         || '';
    my $user          = $query->param('user')        || Foswiki::Func::getWikiName();
    my $public        = $query->param('public')      || '0';
    my $redirectto    = $query->param('redirectto')  || '';    
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup} || "AdminGroup";

    $item_name  = Foswiki::Sandbox::untaintUnchecked($item_name);
    $tag_text   = Foswiki::Sandbox::untaintUnchecked($tag_text);
    $user       = Foswiki::Sandbox::untaintUnchecked($user);
    $public     = Foswiki::Sandbox::untaintUnchecked($public);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);    
    
    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $item_name  = Unicode::MapUTF8::from_utf8( { -string => $item_name,  -charset => $charset } );
    $tag_text   = Unicode::MapUTF8::from_utf8( { -string => $tag_text,   -charset => $charset } );
    $user       = Unicode::MapUTF8::from_utf8( { -string => $user,       -charset => $charset } );
    $public     = Unicode::MapUTF8::from_utf8( { -string => $public,     -charset => $charset } );
    $redirectto = Unicode::MapUTF8::from_utf8( { -string => $redirectto, -charset => $charset } );        

    # sanatize the tag_text
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag_text = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname( $tag_text );

    #
    # checking prerequisites
    #

    # first check the existence of all necessary url parameters
    #
    if ( !$item_name ) {
        $session->{response}->status(400);
        return "<h1>400 'item' parameter missing</h1>";
    }
    if ( !$tag_text ) {
        $session->{response}->status(400);
        return "<h1>400 'tag' parameter missing</h1>";
    }

    # check if current user is allowed to do so
    #
    if ( Foswiki::Func::isGuest() ) {
        $session->{response}->status(401);
        return "<h1>401 Access denied for unauthorized user</h1>";
    }

    # can $currentUser speak for $user? (only for non-public tags)
    #
    if ( $public eq "0" && Foswiki::Func::getWikiName() ne $user ) {
        if ( Foswiki::Func::isGroup($user) ) {
            if (
                !Foswiki::Func::isGroupMember(
                    $user, Foswiki::Func::getWikiName()
                )
              )
            {
                $session->{response}->status(403);
                return "<h1>403 Forbidden</h1>";
            }
        }
        elsif (   !Foswiki::Func::isAnAdmin() 
               && !Foswiki::Func::isGroupMember( $tagAdminGroup, Foswiki::Func::getWikiName() ) ) {
            $session->{response}->status(403);
            return "<h1>403 Forbidden</h1>";
        }
    }

    #
    # actioning
    #
    $session->{response}->status(200);
    
    # handle errors and finally return the number of affected tags
    my $retval;
    my $user_id = Foswiki::Plugins::TagsPlugin::getUserId( Foswiki::Func::isGroup($user) ? $user : Foswiki::Func::getCanonicalUserID( $user ) );

    try {
      $retval  = Foswiki::Plugins::TagsPlugin::Untag::do( $item_name, $tag_text, $user_id, $public );
    } catch Error::Simple with {
      my $e = shift;
      my $n = $e->{'-value'};
      if ( $n == 1  || $n == 2 ) {
        $session->{response}->status(404);
        return "<h1>404 " . $e->{'-text'} . "</h1>";
      } elsif ( $n == 3  || $n == 4 || $n == 5 ) {
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

---++ do( $item_name, $tag_text, $user )
This does untagging.

Takes the following parameters:
 item_name : name of the topic to be untagged (format: Sandbox.TestTopic)
 tag_text  : name of the tag
 user      : Wikiname of the user or group, whose tag shall be deleted (format: JoeDoe) 
 public    : 0 or 1

This routine does not check any prerequisites and/or priviledges. It returns 0, if
the given item_name, tag_text or user_id was not found.

Note: Only use normalized tagnames!

Return:
 number of affected rows/tags.
=cut

sub do {
    my ( $item_name, $tag_text, $cuid, $public ) = @_;
    my $db = new Foswiki::Contrib::DbiContrib;

    # determine item_id for given item_name and exit if its not there
    #
    my $item_id;
    my $statement = sprintf(
        'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type)
    );
    my $arrayRef = $db->dbSelect( $statement, $item_name, 'topic' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $item_id = $arrayRef->[0][0];
    }
    else { throw Error::Simple("Database error: topic not found.", 1); }

    # determine tag_id for given tag_text and exit if its not there
    #
    my $tag_id;
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }
    else { throw Error::Simple("Database error: tag not found.", 2); }


    # now we are ready to actually untag
    #
    $statement =
      sprintf( 'DELETE from %s WHERE %s = ? AND %s = ? AND %s = ? AND %s = ?',
        qw( UserItemTag item_id tag_id user_id public) );
    Foswiki::Func::writeDebug("TagsPlugin::Untag: $statement, $item_id, $tag_id, $cuid, $public" ) if DEBUG;
    my $affected_rows = $db->dbDelete( $statement, $item_id, $tag_id, $cuid, $public );
    if ( $affected_rows eq "0E0" ) { 
      throw Error::Simple("Database warning: nothing there to delete.", 3);
    };
    
    # update statistics
    #
    if ( 0 == 1 ) { # dont update Stats now. leave this job to the garbage collector.
    # if ( $affected_rows > 0 ) {
        # ...in UserTagStat
        $statement =
          sprintf( 'UPDATE %s SET %s=%s-1 WHERE %s = ? AND %s = ?',
            qw( UserTagStat num_items num_items tag_id user_id) );
        Foswiki::Func::writeDebug("TagsPlugin::Untag: $statement, $tag_id, $cuid" ) if DEBUG;
        my $modified = $db->dbInsert( $statement, $tag_id, $cuid );
        if ( $modified eq "0E0" ) { 
          throw Error::Simple("Database error: cannot update user statistics.", 4);
        };

        # ... in TagStat
        $statement =
          sprintf( 'UPDATE %s SET %s=%s-1 WHERE %s = ?',
            qw( TagStat num_items num_items tag_id) );
        Foswiki::Func::writeDebug("TagsPlugin::Untag: $statement, $tag_id" ) if DEBUG;
        $modified = $db->dbInsert( $statement, $tag_id );
        if ( $modified eq "0E0" ) {     
          throw Error::Simple("Database error: cannot update tag statistics.", 5);
        };
    }

    # flushing data to dbms
    #    
    $db->commit();

    # add extra space, so that zero affected rows does not clash with returning "0" from rest invocation
    return " $affected_rows";
}

1;
