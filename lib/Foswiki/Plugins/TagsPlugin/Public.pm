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

package Foswiki::Plugins::TagsPlugin::Public;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0;    # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::publicCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    my $charset = $Foswiki::cfg{Site}{CharSet};

    my $item = $query->param('item') || '';
    my $tag  = $query->param('tag')  || '';
    my $user = $query->param('user') || Foswiki::Func::getWikiName();
    my $publicflag =
      ( defined $query->param('public') ) ? $query->param('public') : '1';
    my $redirectto = $query->param('redirectto') || '';
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup}
      || "AdminGroup";

    $item       = Foswiki::Sandbox::untaintUnchecked($item);
    $tag        = Foswiki::Sandbox::untaintUnchecked($tag);
    $user       = Foswiki::Sandbox::untaintUnchecked($user);
    $publicflag = Foswiki::Sandbox::untaintUnchecked($publicflag);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);

    # input data is assumed to be utf8 (usually in AJAX environments)
    require Unicode::MapUTF8;
    $item =
      Unicode::MapUTF8::from_utf8( { -string => $item, -charset => $charset } );
    $tag =
      Unicode::MapUTF8::from_utf8( { -string => $tag, -charset => $charset } );
    $user =
      Unicode::MapUTF8::from_utf8( { -string => $user, -charset => $charset } );
    $publicflag = Unicode::MapUTF8::from_utf8(
        { -string => $publicflag, -charset => $charset } );
    $redirectto = Unicode::MapUTF8::from_utf8(
        { -string => $redirectto, -charset => $charset } );

    # sanatize the tag
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag);

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
    if ( $publicflag !~ m/^(0|1)$/ ) {
        $session->{response}->status(400);
        return "<h1>400 'public' is not 0 or 1</h1>";
    }

    # can current User speak for $user? (only for non-public tagsi)
    # you can privatize public tags but not vice versa
    #
    if ( $publicflag eq "1" && Foswiki::Func::getWikiName() ne $user ) {
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
        elsif (
            !Foswiki::Func::isAnAdmin()
            && !Foswiki::Func::isGroupMember(
                $tagAdminGroup, Foswiki::Func::getWikiName()
            )
          )
        {
            $session->{response}->status(403);
            return "<h1>403 Forbidden</h1>";
        }
    }

    #
    # actioning
    #
    $session->{response}->status(200);

    # handle errors and return the number of affected tags
    my $retval;
    my $user_id =
      Foswiki::Plugins::TagsPlugin::Db::createUserID(
        Foswiki::Func::isGroup($user)
        ? $user
        : Foswiki::Func::getCanonicalUserID($user) );

    try {
        $retval =
          Foswiki::Plugins::TagsPlugin::Public::do( $item, $tag, $user_id,
            $publicflag );
    }
    catch Error::Simple with {
        my $e    = shift;
        my $code = $e->{'-value'};
        my $text = $e->{'-text'};
        $session->{response}->status($code);
        return "<h1>$code $text</h1>";
    };

    # redirect on request
    if ($redirectto) {
        my ( $rweb, $rtopic ) =
          Foswiki::Func::normalizeWebTopicName( undef, $redirectto );
        my $url = Foswiki::Func::getScriptUrl( $rweb, $rtopic, "view" );
        Foswiki::Func::redirectCgiQuery( undef, $url );
    }

    return $retval;
}

=begin TML

---++ do( %item, $tag_text, $user_id, $public )
This sets or unsets the public flag of a given topic/tag/user tupel.

Takes the following parameters:
 item      : web.topic name
 tag_text  : name of the tag
 user_id   : wikiname, defaults to current user
 public    : 0 or 1

This routine does not check any prerequisites and/or priviledges.

Note: Only use normalized tagnames!

Return:
 TODO: something 
=cut

sub do {
    my ( $item, $tag_text, $user_id, $public ) = @_;
    Foswiki::Func::writeDebug(
        "TagsPlugin::Public::do( $item, $tag_text, $user_id, $public )")
      if DEBUG;
    my $db     = new Foswiki::Contrib::DbiContrib;
    my $retval = "";

    # determine item_id for given item and exit if its not there
    my $item_id = Foswiki::Plugins::TagsPlugin::Db::getItemID($item);
    if ( $item_id eq "0E0" ) {
        throw Error::Simple( "Database error: topic not found.", 404 );
    }

    # determine tag_id for given tag_text and exit if its not there
    my $tag_id = Foswiki::Plugins::TagsPlugin::Db::getTagID($tag_text);
    if ( $tag_id eq "0E0" ) {
        throw Error::Simple( "Database error: tag not found.", 404 );
    }

    # if public=1: check, if there is already a public tag
    #
    if ( $public eq "1" ) {
        my $statement =
          sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ? AND %s = ?',
            qw( public UserItemTag item_id tag_id public ) );
        Foswiki::Func::writeDebug(
            "TagsPlugin::Public: $statement, $item_id, $tag_id, 1")
          if DEBUG;
        my $arrayRef = $db->dbSelect( $statement, $item_id, $tag_id, 1 );
        if ( defined( $arrayRef->[0][0] ) ) {
            if ( $arrayRef->[0][0] == "1" ) {
                throw Error::Simple( "There is already a public tag.", 500 );
            }
        }
    }

    # now we are ready to actually update
    # try to update the tupel. dont care, if it exists.
    my $affected_rows = 0;
    my $statement     = sprintf(
'UPDATE %s SET public = ? WHERE %s = ? AND %s = ? AND %s = ? AND public = ?',
        qw( UserItemTag item_id tag_id user_id ) );
    my $affected_rows =
      $db->dbInsert( $statement, $public, $item_id, $tag_id, $user_id,
        $public == "0" ? 1 : 0 );
    Foswiki::Func::writeDebug(
"TagsPlugin::Public: $statement, pub:$public, item:$item_id, tag:$tag_id, user:$user_id"
    ) if DEBUG;
    if ( $affected_rows eq "0E0" ) { $affected_rows = 0; }
    $retval = "$affected_rows";

    # flushing data to dbms
    $db->commit();

    return $retval;
}

1;
