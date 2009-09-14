# This script Copyright 
# (c) 2008-2009, SvenDowideit@fosiki.com
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
# Author(s): Sven Dowideit, Oliver Krueger

package Foswiki::Plugins::TagsPlugin::Tag;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::tagCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};

    my $item_name     = $query->param('item');
    my $item_type     = $query->param('type')                    || 'topic';
    my $tag_text      = $query->param('tag');
    my $redirectto    = $query->param('redirectto')              || '';
    my $user          = $query->param('user')                    || Foswiki::Func::getWikiName();
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup} || "AdminGroup";    

    $item_name  = Foswiki::Sandbox::untaintUnchecked($item_name);
    $item_type  = Foswiki::Sandbox::untaintUnchecked($item_type);
    $tag_text   = Foswiki::Sandbox::untaintUnchecked($tag_text);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);
    $user       = Foswiki::Sandbox::untaintUnchecked($user);

    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $item_name  = Unicode::MapUTF8::from_utf8( { -string => $item_name,  -charset => $charset } );
    $item_type  = Unicode::MapUTF8::from_utf8( { -string => $item_type,  -charset => $charset } );
    $tag_text   = Unicode::MapUTF8::from_utf8( { -string => $tag_text,   -charset => $charset } );
    $redirectto = Unicode::MapUTF8::from_utf8( { -string => $redirectto, -charset => $charset } );
    $user       = Unicode::MapUTF8::from_utf8( { -string => $user,       -charset => $charset } );

    #
    # checking prerequisites
    #

    # first check the existence of all necessary url parameters
    #
    if ( !$item_name ) {
        $session->{response}->status(400);
        return "<h1>400 'item_name' parameter missing</h1>";
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

    # can $currentUser speak for $user_id?
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
    elsif (    Foswiki::Func::getWikiName() ne $user 
           && !Foswiki::Func::isAnAdmin() 
           && !Foswiki::Func::isGroupMember( $tagAdminGroup, Foswiki::Func::getWikiName() ) ) {

        $session->{response}->status(403);
        return "<h1>403 Forbidden</h1>";
    }

    #
    # actioning
    #
    $session->{response}->status(200);
    
    # returning nothing of interest
    my $retval;
    my $user_id = Foswiki::Plugins::TagsPlugin::getUserId($session, Foswiki::Func::getCanonicalUserID( $user ) );
    Foswiki::Func::writeDebug("ID: $user_id") if DEBUG;

    try {
      $retval = Foswiki::Plugins::TagsPlugin::Tag::do( $item_type, $item_name, $tag_text, $user_id );
    } catch Error::Simple with {
      my $e = shift;
      my $n = $e->{'-value'};
      if ( $n == 1 || $n == 2 ) {
        $session->{response}->status(400);
        return "<h1>400 " . $e->{'-text'} . "</h1>";
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

---++ do( $item_type, $item_name, $tag_text, $user_id )
This does tagging.

Takes the following parameters:
 item_type : either "topic" or "tag"
 item_name : name of the topic to be tagged (format: Sandbox.TestTopic)
 tag_text  : name of the tag
 user_id   : tagsplugin user_id (not Foswiki cUID) 

This routine does not check any prerequisites and/or priviledges.

Return:
 nothing
=cut

sub do {
    my ( $item_type, $item_name, $tag_text, $user_id ) = @_;

    throw Error::Simple("tag parameter missing", 1) unless ( ( defined($tag_text) )  && ( $tag_text  ne '' ) );
    throw Error::Simple("item parameter missing", 2) unless ( ( defined($item_name) ) && ( $item_name ne '' ) );

    my $db = new Foswiki::Contrib::DbiContrib;
    my $item_id;
    my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    my $arrayRef = $db->dbSelect( $statement, $item_name, $item_type );
    if ( defined( $arrayRef->[0][0] ) ) {
        $item_id = $arrayRef->[0][0];
    }
    else {
        $statement = sprintf( 'INSERT INTO %s (%s, %s) VALUES (?,?)',
            qw( Items item_name item_type) );
        my $rowCount = $db->dbInsert( $statement, $item_name, $item_type );
        $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
            qw( item_id Items item_name item_type) );
        $arrayRef = $db->dbSelect( $statement, $item_name, $item_type );
        $item_id = $arrayRef->[0][0];
    }

    my $tag_id;
    my $new_tag = 0;
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }
    else {
        $statement = sprintf( 'INSERT INTO %s (%s,%s) VALUES (?,?)',
            qw(Items item_name item_type) );
        my $rowCount = $db->dbInsert( $statement, $tag_text, 'tag' );
        $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
            qw(item_id Items item_name item_type) );
        $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
        $tag_id = $arrayRef->[0][0];

        $statement =
          sprintf( 'INSERT INTO %s (%s) VALUES (?)', qw( TagStat tag_id) );
        $db->dbInsert( $statement, $tag_id );
        $statement = sprintf( 'INSERT INTO %s (%s,%s) VALUES (?,?)',
            qw( UserTagStat tag_id user_id) );
        $db->dbInsert( $statement, $tag_id, $user_id );
        $new_tag = 1;
    }

    my $rowCount = 0;
    $statement =
      sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ? AND %s = ?',
        qw(tag_id UserItemTag user_id item_id tag_id) );
    $arrayRef = $db->dbSelect( $statement, $user_id, $item_id, $tag_id );
    if ( !defined( $arrayRef->[0][0] ) ) {
        $statement = sprintf( 'INSERT INTO %s (%s, %s, %s) VALUES (?,?,?)',
            qw( UserItemTag user_id item_id tag_id) );
        $rowCount = $db->dbInsert( $statement, $user_id, $item_id, $tag_id );

        unless ($new_tag) {
            $statement = sprintf( 'UPDATE %s SET %s=%s+1 WHERE %s = ?',
                qw( TagStat num_items num_items tag_id) );
            my $modified = $db->dbInsert( $statement, $tag_id );
            if ( $modified == 0 ) {
                $statement = sprintf( 'INSERT INTO %s (%s) VALUES (?)',
                    qw( TagStat tag_id) );
                $db->dbInsert( $statement, $tag_id );
            }
            $statement =
              sprintf( 'UPDATE %s SET %s=%s+1 WHERE %s = ? AND %s = ?',
                qw( UserTagStat num_items num_items tag_id user_id) );
            $modified = $db->dbInsert( $statement, $tag_id, $user_id );
            if ( $modified == 0 ) {
                $statement = sprintf( 'INSERT INTO %s (%s,%s) VALUES (?,?)',
                    qw( UserTagStat tag_id user_id) );
                $db->dbInsert( $statement, $tag_id, $user_id );
            }
        }
    }
    
    # flushing the changes
    $db->commit();

    return $rowCount;
}

1;
