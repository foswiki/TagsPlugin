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

package Foswiki::Plugins::TagsPlugin::ChangeOwner;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::changeOwnerCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};    

    my $item       = $query->param('item')       || '';
    my $tag        = $query->param('tag')        || '';
    my $user       = $query->param('user')       || Foswiki::Func::getWikiName();
    my $newuser    = $query->param('newuser')    || $user;
    my $publicflag = (defined $query->param('public')) ? $query->param('public') : '1';
    my $redirectto = $query->param('redirectto') || '';    

    $item       = Foswiki::Sandbox::untaintUnchecked($item);
    $tag        = Foswiki::Sandbox::untaintUnchecked($tag);
    $user       = Foswiki::Sandbox::untaintUnchecked($user);
    $newuser    = Foswiki::Sandbox::untaintUnchecked($newuser);
    $publicflag = Foswiki::Sandbox::untaintUnchecked($publicflag);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);    
    
    # input data is assumed to be utf8 (usually in AJAX environments) 
    require Unicode::MapUTF8;
    $item       = Unicode::MapUTF8::from_utf8( { -string => $item,       -charset => $charset } );
    $tag        = Unicode::MapUTF8::from_utf8( { -string => $tag,        -charset => $charset } );
    $user       = Unicode::MapUTF8::from_utf8( { -string => $user,       -charset => $charset } );
    $newuser    = Unicode::MapUTF8::from_utf8( { -string => $newuser,    -charset => $charset } );
    $publicflag = Unicode::MapUTF8::from_utf8( { -string => $publicflag, -charset => $charset } );
    $redirectto = Unicode::MapUTF8::from_utf8( { -string => $redirectto, -charset => $charset } );    

    # sanatize the tag
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname( $tag );

    Foswiki::Func::writeDebug("Foswiki::TagsPlugin::ChangeOwner::rest( $item $tag $user $newuser $publicflag $redirectto )") if DEBUG;

    #
    # checking prerequisites
    #

    # first check the existence of all necessary url parameters
    #
    if ( !$tag ) {
        $session->{response}->status(400);
        return "<h1>400 'tag' parameter missing</h1>";
    }
    if ( !$item ) { 
        $session->{response}->status(400);
        return "<h1>400 'item' parameter missing</h1>";
    } 
    if ( !$user ) {
        $session->{response}->status(400);
        return "<h1>400 'user' parameter missing</h1>";
    }
    if ( $publicflag !~ m/^(0|1)$/ ) {
        $session->{response}->status(400);
        return "<h1>400 'public' is not 0 or 1</h1>";
    }

    if ( $user ne Foswiki::Func::getWikiName() && not Foswiki::Func::isGroupMember( $user, Foswiki::Func::getWikiName() ) ) {
        $session->{response}->status(403);
        return "<h1>403 Forbidden</h1>";
    }


    #
    # actioning
    #
    $session->{response}->status(200);
    
    my $retval;
    my $user_id    = Foswiki::Plugins::TagsPlugin::getUserId( Foswiki::Func::isGroup($user) ? $user : Foswiki::Func::getCanonicalUserID( $user ) );
    my $newuser_id = Foswiki::Plugins::TagsPlugin::getUserId( Foswiki::Func::isGroup($newuser) ? $newuser : Foswiki::Func::getCanonicalUserID( $newuser ) );

    # handle errors and return the number of affected tags
    try {
       $retval = Foswiki::Plugins::TagsPlugin::ChangeOwner::do( $item, $tag, $user_id, $newuser_id, $publicflag );
    } catch Error::Simple with {
      my $e = shift;
      my $n = $e->{'-value'};
      if ( $n == 1  || $n == 2 ) {
        $session->{response}->status(404);
        return "<h1>404 " . $e->{'-text'} . "</h1>";
      } elsif ( $n == 3 ) {
        $session->{response}->status(500);
        return "<h1>500 " . $e->{'-text'} . "</h1>";
      } else {
        $e->throw();
      }
    };
    
    # redirect on request
    if ( $redirectto ) {
        my ($rweb, $rtopic) = Foswiki::Func::normalizeWebTopicName( undef, $redirectto );
        my $url = Foswiki::Func::getScriptUrl( $rweb, $rtopic, "view" );
        Foswiki::Func::redirectCgiQuery( undef, $url );
    }    

    return $retval;
}

=begin TML

---++ do( %item, $tag_text, $user_id, $newuser_id, $public )
This sets or unsets the public flag of a given topic/tag/user tupel.

Takes the following parameters:
 item       : web.topic name
 tag_text   : name of the tag
 user_id    : wikiname, defaults to current user # SMELL update!
 newuser_id : database cuid for the new user
 public     : 0 or 1

This routine does not check any prerequisites and/or priviledges.

Note: Only use normalized tagnames!

Return:
 TODO: something 
=cut

sub do {
    my ( $item, $tag_text, $user_id, $newuser_id, $public ) = @_;
    Foswiki::Func::writeDebug("TagsPlugin::ChangeOwner::do( $item, $tag_text, $user_id, $newuser_id, $public )") if DEBUG;
    my $db = new Foswiki::Contrib::DbiContrib;
    my $retval = "";

    # determine tag_id for given tag_text and exit if its not there
    #
    my $tag_id;
    my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    Foswiki::Func::writeDebug("TagsPlugin::Public: $statement, $tag_text, tag") if DEBUG;
    my $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }
    else { 
      throw Error::Simple("Database error: tag not found.", 1);
    }

    # determine item_id for given item and exit if its not there
    #   
    my $item_id;
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    Foswiki::Func::writeDebug("TagsPlugin::Public: $statement, $item, topic" ) if DEBUG;
    $arrayRef = $db->dbSelect( $statement, $item, 'topic' );
    if ( defined( $arrayRef->[0][0] ) ) { 
        $item_id = $arrayRef->[0][0];
    }   
    else { 
      throw Error::Simple("Database error: item not found.", 2); 
    }

    # check, if there is already that tag for the new user
    #
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ? AND %s = ? AND %s = ?',
        qw( user_id UserItemTag item_id tag_id user_id public ) );
    Foswiki::Func::writeDebug("TagsPlugin::Public: $statement, $item_id, $tag_id, $newuser_id, $public" ) if DEBUG;
    $arrayRef = $db->dbSelect( $statement, $item_id, $tag_id, $newuser_id, $public );
    if ( defined( $arrayRef->[0][0] && $arrayRef->[0][0] == $newuser_id) ) { 
  Foswiki::Func::writeDebug($newuser_id ) if DEBUG;
      throw Error::Simple("This tag already exists.", 3); 
    }

    # now we are ready to actually update
    #
    # try to update the tupel. dont care, if it exists. 
    #
    my $affected_rows = 0;
    $statement = sprintf( 'UPDATE %s SET %s = ? WHERE %s = ? AND %s = ? AND %s = ? AND %s = ?',
      qw( UserItemTag user_id item_id tag_id user_id public ) );
    Foswiki::Func::writeDebug("TagsPlugin::ChangeOwner: $statement, pub:$public, item:$item_id, tag:$tag_id, user:$user_id newuser:$newuser_id" ) if DEBUG;
    $affected_rows = $db->dbInsert( $statement, $newuser_id, $item_id, $tag_id, $user_id, $public );
    if ( $affected_rows eq "0E0" ) { $affected_rows=0; };
    $retval = "$affected_rows";

    # SMELL: We might need to update some Stat tables here

    # flushing data to dbms
    #    
    $db->commit();

    return $retval;
}

1;
