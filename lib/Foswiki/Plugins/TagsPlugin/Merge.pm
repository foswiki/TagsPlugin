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
use Encode ();

use constant DEBUG => 0;    # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::mergeCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    my $tag1       = $query->param('tag1')       || '';
    my $tag2       = $query->param('tag2')       || '';
    my $redirectto = $query->param('redirectto') || '';

    $tag1       = Foswiki::Sandbox::untaintUnchecked($tag1);
    $tag2       = Foswiki::Sandbox::untaintUnchecked($tag2);
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
        Encode::from_to( $tag1,       "utf8", $site_charset );
        Encode::from_to( $tag2,       "utf8", $site_charset );
        Encode::from_to( $redirectto, "utf8", $site_charset );
    }

    # sanatize the tag_text
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag1 = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag1);
    $tag2 = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag2);

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
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup}
      || "AdminGroup";
    if (
        !Foswiki::Func::isGroupMember(
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

    # returning 0 on failure and some other positive number on success
    my $retval;

    try {
        $retval = Foswiki::Plugins::TagsPlugin::Merge::do( $tag1, $tag2 );
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

---++ do( $tag1, $tag2 )
This does the merging. Updates both Stat tables and deletes unused entries for obsolete tag2.

Takes the following parameters:
 tag1 : name of the tag which remains
 tag2 : name of the tag which will be merged into tag1

This routine does not check any prerequisites and/or priviledges. It returns 0, if
tag1 or tag2 was not found.

Note: Only use normalized tagnames!

Return:
 0 on failure, any other positive number on success.
=cut

sub do {
    my ( $tag1, $tag2 ) = @_;
    my $db = new Foswiki::Contrib::DbiContrib;

    # determine tag_id for given tag1 and exit if its not there
    my $tag_id1 = Foswiki::Plugins::TagsPlugin::Db::getTagID($tag1);
    if ( $tag_id1 eq "0E0" ) {
        throw Error::Simple( "Database error: tag1 not found.", 404 );
    }

    # determine tag_id for given tag2 and exit if its not there
    my $tag_id2 = Foswiki::Plugins::TagsPlugin::Db::getTagID($tag2);
    if ( $tag_id2 eq "0E0" ) {
        throw Error::Simple( "Database error: tag2 not found.", 404 );
    }

    # merge the tags (in UserItemTag)
    # IGNOREing duplicate entries, which usually occur
    # (may leave some garbage behind, which is handled by "purge" in next step)
    #
    my $statement = sprintf( 'UPDATE IGNORE %s SET %s = ? WHERE %s = ?',
        qw( UserItemTag tag_id tag_id ) );
    my $affected_rows = $db->dbInsert( $statement, $tag_id1, $tag_id2 );
    Foswiki::Func::writeDebug(
        "Merge: $statement; ($tag_id1, $tag_id2) -> $affected_rows")
      if DEBUG;
    if ( $affected_rows eq "0E0" ) {
        throw Error::Simple( "Database error: failed to update the tags.",
            500 );
    }

    # handle clashing public tags
    Foswiki::Plugins::TagsPlugin::Db::handleDuplicatePublics();

    # purge tag2
    if ( Foswiki::Plugins::TagsPlugin::Db::deleteTag($tag_id2) eq "0E0" ) {
        throw Error::Simple( "Database error: failed to delete tag2.", 500 );
    }

    # update stats in TagStat
    if ( Foswiki::Plugins::TagsPlugin::Db::updateTagStat($tag_id1) eq "0E0" ) {
        throw Error::Simple( "Database error: failed to update TagStat.", 500 );
    }

    # update stats in UserTagStat for all users, who have a relation to this tag
    if ( Foswiki::Plugins::TagsPlugin::Db::updateUserTagStatAll($tag_id1) eq
        "0E0" )
    {
        throw Error::Simple( "Database error: failed to update UserTagStat.",
            500 );
    }

    $db->commit();

    # add extra space, so that zero affected rows does not clash
    # with returning "0" from rest invocation
    return " $affected_rows";
}

1;
