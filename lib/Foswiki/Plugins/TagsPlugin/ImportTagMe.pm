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

package Foswiki::Plugins::TagsPlugin::ImportTagMe;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 1; # toggle me

=begin TML

---++ rest( $session )
see Foswiki::Plugins::TagsPlugin::ImportTagMeCall()

=cut

sub rest {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    my $public  = $query->param('public') || "NULL";

    # check if current user is allowed to do so
    #
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup} || "AdminGroup";
    if ( !Foswiki::Func::isGroupMember( $tagAdminGroup, Foswiki::Func::getWikiName()) ) {
        $session->{response}->status(403);
        return "<h1>403 Forbidden</h1>";
    }

    # interpret the public url param as a confirmation
    if ( $public eq "0" || $public eq "1" ) { 
        $public = Foswiki::Sandbox::untaintUnchecked($public);
        return Foswiki::Plugins::TagsPlugin::ImportTagMe::do( $public );
    } else {
        return "Please use ?public=0 or 1"; 
    }   
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
    my ( $public ) = @_;

    Foswiki::Func::writeDebug("TagsPlugin:TagMe-Import:Start") if DEBUG;

    $public = $public ? "1" : "0";
    my $lineRegex = "^0*([0-9]+), ([^,]+), (.*)";


    # get list if _tag_ files containing the tags for each topic
    my $workAreaDir = Foswiki::Func::getWorkArea( "TagMePlugin" );
    my @list = ();
    if ( opendir( DIR, "$workAreaDir" ) ) {
        my @files =
          grep { !/^_tags_all\.txt$/ } grep { /^_tags_.*\.txt$/ } readdir(DIR);
        closedir DIR; 
        @list = map { s/^_tags_(.*)\.txt$/$1/; $_ } @files;
    }

    # loop through all topics / files
    use Foswiki::Plugins::TagsPlugin::Tag;
    foreach my $webTopic ( @list ) {
      $webTopic =~ s/[\/\\]/\./g;
      my $text = Foswiki::Func::readFile("$workAreaDir/_tags_$webTopic.txt");
      my @tagInfo = grep { /^[0-9]/ } split( /\n/, $text );
      foreach my $line ( @tagInfo ) {
        if ( $line =~ /$lineRegex/ ) {
          my $num   = $1;
          my $tag   = $2;
          my @users = split( /,\s*/, $3 );
          foreach my $user ( @users ) {
            my $user_id = Foswiki::Plugins::TagsPlugin::getUserId( Foswiki::Func::getCanonicalUserID( $user ) );
            Foswiki::Func::writeDebug("TagsPlugin:TagMe-Import: $webTopic, $tag, $user_id, $public") if DEBUG;
            Foswiki::Plugins::TagsPlugin::Tag::do( "tag", $webTopic, $tag, $user_id, $public );
          }
        }
      }
    }

    Foswiki::Func::writeDebug("TagsPlugin:TagMe-Import:End") if DEBUG;

    return "done";
}

1;
