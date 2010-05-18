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
use Encode ();

use constant DEBUG => 0;    # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::deleteCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    my $tag_text   = $query->param('tag')        || '';
    my $redirectto = $query->param('redirectto') || '';
    $tag_text   = Foswiki::Sandbox::untaintUnchecked($tag_text);
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
        Encode::from_to( $tag_text,   "utf8", $site_charset );
        Encode::from_to( $redirectto, "utf8", $site_charset );
    }

    # sanatize the tag_text
    use Foswiki::Plugins::TagsPlugin::Func;
    $tag_text = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($tag_text);

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

    # handle errors and return the number of affected tags
    my $retval;

    try {
        $retval = Foswiki::Plugins::TagsPlugin::Delete::do($tag_text);
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

---++ do( $tag_text )
This does the delete including all (user) instances of the tag.

Takes the following parameters:
 tag_text  : name of the tag

This routine does not check any prerequisites and/or priviledges. It returns 0, if
the given tag_text was not found.

Note: Only use normalized tagnames!

Return:
   * 1 on success
=cut

sub do {
    my ($tag_text) = @_;

    # determine tag_id for given tag_text and exit if its not there
    my $tag_id = Foswiki::Plugins::TagsPlugin::Db::getTagID($tag_text);
    if ( $tag_id eq "0E0" ) {
        throw Error::Simple( "Database error: tag not found.", 404 );
    }

    # delete tag
    my $retval = Foswiki::Plugins::TagsPlugin::Db::deleteTag($tag_id);
    if ( $retval eq "0E0" ) {
        throw Error::Simple( "Database error: failed to delete tag.", 500 );
    }

    return $retval;
}

1;
