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
use Encode ();

use constant DEBUG => 0;    # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::renameCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    my $tag_old    = $query->param('oldtag')     || '';
    my $tag_new    = $query->param('newtag')     || '';
    my $redirectto = $query->param('redirectto') || '';

    $tag_old    = Foswiki::Sandbox::untaintUnchecked($tag_old);
    $tag_new    = Foswiki::Sandbox::untaintUnchecked($tag_new);
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
        Encode::from_to( $tag_old,    "utf8", $site_charset );
        Encode::from_to( $tag_new,    "utf8", $site_charset );
        Encode::from_to( $redirectto, "utf8", $site_charset );
    }

    # sanatize the tag_text
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag_old = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag_old);
    $tag_new = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag_new);

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

    # returning the number of affected tags
    my $retval;
    try {
        $retval =
          Foswiki::Plugins::TagsPlugin::Rename::do( $tag_old, $tag_new );
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

---++ do( $tag_old, $tag_new )
This does untagging.

Takes the following parameters:
 tag_old : name of tag to be renamed
 tag_new : new name for the old tag

This routine does not check any prerequisites and/or priviledges. It returns 0, if
the old tagname was not found or the new tagname already exists.

Note: Only use normalized tagnames!

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
    else {
        throw Error::Simple( "Database error: tag_old not found.", 404 );
    }

    # check if new tagname already exists by probing for an tag_id
    #
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag_new, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        throw Error::Simple( "Database error: tag_new already exists.", 409 );
    }

    # now we are ready to actually rename
    #
    $statement = sprintf( 'UPDATE %s SET %s = ? WHERE %s = ?',
        qw( Items item_name item_id ) );
    Foswiki::Func::writeDebug("Rename: $statement; ($tag_new, $tag_id)")
      if DEBUG;
    my $affected_rows = $db->dbInsert( $statement, $tag_new, $tag_id );
    if ( $affected_rows eq "0E0" ) {
        throw Error::Simple( "Database error: failed to rename the tag.", 500 );
    }

    # flushing data to dbms
    #
    $db->commit();

# add extra space, so that zero affected rows does not clash with returning "0" from rest invocation
    return " $affected_rows";
}

1;
