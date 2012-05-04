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
use Encode ();

use constant DEBUG => 0;    # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::changeOwnerCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    my $item    = $query->param('item')    || '';
    my $tag     = $query->param('tag')     || '';
    my $user    = $query->param('user')    || Foswiki::Func::getWikiName();
    my $newuser = $query->param('newuser') || $user;
    my $publicflag =
      ( defined $query->param('public') ) ? $query->param('public') : '1';
    my $redirectto = $query->param('redirectto') || '';

    my $current_user  = Foswiki::Func::getWikiName();
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup}
      || "AdminGroup";

    $item       = Foswiki::Sandbox::untaintUnchecked($item);
    $tag        = Foswiki::Sandbox::untaintUnchecked($tag);
    $user       = Foswiki::Sandbox::untaintUnchecked($user);
    $newuser    = Foswiki::Sandbox::untaintUnchecked($newuser);
    $publicflag = Foswiki::Sandbox::untaintUnchecked($publicflag);
    $redirectto = Foswiki::Sandbox::untaintUnchecked($redirectto);

    # handle utf8 if necessary
    my $site_charset = $Foswiki::cfg{Site}{CharSet} || "iso-8859-1";
    my $remote_charset = $site_charset;
    if ( $session->{request}->header( -name => "Content-Type" ) =~
        m/charset=([^;\s]+)/i )
    {
        $remote_charset = $1;
    }

    if (   $site_charset !~ /^utf-?8$/i
        && $remote_charset =~ /^utf-?8$/i )
    {
        Encode::from_to( $item,       "utf8", $site_charset );
        Encode::from_to( $tag,        "utf8", $site_charset );
        Encode::from_to( $user,       "utf8", $site_charset );
        Encode::from_to( $newuser,    "utf8", $site_charset );
        Encode::from_to( $publicflag, "utf8", $site_charset );
        Encode::from_to( $redirectto, "utf8", $site_charset );
    }

    # sanatize the tag
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag);

    Foswiki::Func::writeDebug(
"Foswiki::TagsPlugin::ChangeOwner::rest( $item $tag $user $newuser $publicflag $redirectto )"
    ) if DEBUG;

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

    if (
        $user ne $current_user
        && not Foswiki::Func::isGroupMember(
            $tagAdminGroup, Foswiki::Func::getWikiName()
        )
      )
    {
        $session->{response}->status(403);
        return "<h1>403 Forbidden</h1>";
    }

    #
    # actioning
    #
    $session->{response}->status(200);

    my $retval;
    my $user_id = Foswiki::Plugins::TagsPlugin::Db::createUserID(
        Foswiki::Func::isGroup($user)
        ? $user
        : Foswiki::Func::getCanonicalUserID($user)
    );
    my $newuser_id = Foswiki::Plugins::TagsPlugin::Db::createUserID(
        Foswiki::Func::isGroup($newuser)
        ? $newuser
        : Foswiki::Func::getCanonicalUserID($newuser)
    );

    # handle errors and return the number of affected tags
    try {
        $retval =
          Foswiki::Plugins::TagsPlugin::ChangeOwner::do( $item, $tag, $user_id,
            $newuser_id, $publicflag );
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
    Foswiki::Func::writeDebug(
"TagsPlugin::ChangeOwner::do( $item, $tag_text, $user_id, $newuser_id, $public )"
    ) if DEBUG;
    my $db     = new Foswiki::Contrib::DbiContrib;
    my $retval = "";

    # determine tag_id for given tag_text and exit if its not there
    my $tag_id = Foswiki::Plugins::TagsPlugin::Db::getTagID($tag_text);
    if ( $tag_id eq "0E0" ) {
        throw Error::Simple( "Database error: tag not found.", 404 );
    }

    # determine item_id for given item and exit if its not there
    my $item_id = Foswiki::Plugins::TagsPlugin::Db::getItemID($item);
    if ( $item_id eq "0E0" ) {
        throw Error::Simple( "Database error: topic not found.", 404 );
    }

    # check, if there is already that tag for the new user
    my $statement = sprintf(
        'SELECT %s from %s WHERE %s = ? AND %s = ? AND %s = ? AND %s = ?',
        qw( user_id UserItemTag item_id tag_id user_id public ) );
    Foswiki::Func::writeDebug(
"TagsPlugin::Public: $statement, $item_id, $tag_id, $newuser_id, $public"
    ) if DEBUG;
    my $arrayRef =
      $db->dbSelect( $statement, $item_id, $tag_id, $newuser_id, $public );
    if ( defined( $arrayRef->[0][0] && $arrayRef->[0][0] == $newuser_id ) ) {
        throw Error::Simple( "This tag already exists.", 400 );
    }

    # now we are ready to actually update
    # try to update the tupel. dont care, if it exists.
    my $affected_rows = 0;
    $statement = sprintf(
        'UPDATE %s SET %s = ? WHERE %s = ? AND %s = ? AND %s = ? AND %s = ?',
        qw( UserItemTag user_id item_id tag_id user_id public ) );
    Foswiki::Func::writeDebug(
"TagsPlugin::ChangeOwner: $statement, pub:$public, item:$item_id, tag:$tag_id, user:$user_id newuser:$newuser_id"
    ) if DEBUG;
    $affected_rows =
      $db->dbInsert( $statement, $newuser_id, $item_id, $tag_id, $user_id,
        $public );
    if ( $affected_rows eq "0E0" ) { $affected_rows = 0; }
    $retval = " $affected_rows";

    # update stats in UserTagStat for user_id
    if (
        Foswiki::Plugins::TagsPlugin::Db::updateUserTagStat(
            $tag_id, $user_id
        ) eq "0E0"
      )
    {
        throw Error::Simple( "Database error: failed to update UserTagStat.",
            500 );
    }

    # update stats in UserTagStat for newuser_id
    if (
        Foswiki::Plugins::TagsPlugin::Db::updateUserTagStat( $tag_id,
            $newuser_id ) eq "0E0"
      )
    {
        throw Error::Simple( "Database error: failed to update UserTagStat.",
            500 );
    }

    # flushing data to dbms
    $db->commit();

    return $retval;
}

1;
