# This script Copyright
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
# Author(s): Oliver Krueger

package Foswiki::Plugins::TagsPlugin::TAGSEARCH;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0;    # toggle me

=begin TML

---++ do( $session, $params, $topic, $web )
Taghandler for TAGSEARCH.

Return:
 Formatted search result.
=cut

sub do {
    my ( $session, $params, $topic, $web ) = @_;

    my $theHeader    = $params->{header}     || '';
    my $theSep       = $params->{separator}  || $params->{sep} || ', ';
    my $theFooter    = $params->{footer}     || '';
    my $theUser      = $params->{user}       || 'all';
    my $theWeb       = $params->{web}        || 'all';
    my $theTag       = $params->{tag}        || 'all';
    my $theTopic     = $params->{topic}      || '';
    my $theQuery     = $params->{query}      || 'tag';
    my $theOrder     = $params->{order}      || '';
    my $thePublic    = $params->{visibility} || 'user';
    my $theAlt       = $params->{alt}        || '';
    my $theLimit     = $params->{limit}      || 0;
    my $theOffset    = $params->{offset}     || 0;
    my $theFormat    = $params->{format};
    my $theRendering = $params->{rendering}  || '';

    if ( $thePublic =~ m/private/i ) {
        $theUser = Foswiki::Func::getWikiName();
    }

    use Foswiki::Plugins::TagsPlugin::Func;
    $theTag = Foswiki::Plugins::TagsPlugin::Func::normalizeTagname($theTag);

    # determine default format based on query type
    unless ($theFormat) {
        if ( $theQuery eq "user" ) {
            $theFormat = '$user';
        }
        elsif ( $theQuery eq "topic" ) {
            $theFormat = '[[$item][$topic]]';
        }
        else {
            $theFormat = '$tag';
        }
    }

    if ( $theRendering =~ /^cloud$/i ) {
        $theFormat = '$tag:1:$web:$topic:$user';
        $theQuery  = "tag";
        $theSep    = ",";
    }

    my $isTagAdmin =
      Foswiki::Func::isGroupMember( $Foswiki::cfg{TagsPlugin}{TagAdminGroup}
          || "AdminGroup" ) ? 1 : 0;

    if ( $thePublic =~ /^all$/i && !$isTagAdmin ) {
        $thePublic = "user";
    }

    my $output    = '';
    my $statement = '';
    my @whereClauses;

    my $db = new Foswiki::Contrib::DbiContrib;

    # resolve the cUID from the database and exit with "" if it does not exist
    #
    if ( lc($theUser) ne 'all' ) {
        my @users = split( /,/, $theUser );
        my @clauses;
        foreach my $u (@users) {
            $u =~ s/^\s*//g;
            $u =~ s/\s*$//g;
            my $cuid;
            my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? ',
                qw( CUID Users FoswikicUID) );
            my $arrayRef = $db->dbSelect( $statement,
                Foswiki::Func::isGroup($u)
                ? $u
                : Foswiki::Func::getCanonicalUserID($u) );
            if ( defined( $arrayRef->[0][0] ) ) {
                $cuid = $arrayRef->[0][0];
            }
            next unless ( defined($cuid) );
            push @clauses, " i2t.user_id = '$cuid' ";
        }
        if ( @clauses == 0 ) { return ''; }
        push @whereClauses, "(" . join( ' OR ', @clauses ) . ")";
    }

    # filter for webs
    #
    if ( $theWeb ne 'all' ) {
        my @webs = split( /,/, $theWeb );
        my @clauses;
        foreach my $w (@webs) {
            $w =~ s/^\s*//g;
            $w =~ s/\s*$//g;
            push @clauses, " i.item_name like '$w%' ";
        }
        push @whereClauses, "(" . join( ' OR ', @clauses ) . ")";
    }

    # filter for topics
    #
    if ($theTopic) {
        my @topics = split( /,/, $theTopic );
        my @clauses;
        foreach my $t (@topics) {
            $t =~ s/^\s*//g;
            $t =~ s/\s*$//g;
            push @clauses, " i.item_name like '%.$t' ";
        }
        push @whereClauses, join( ' OR ', @clauses );
    }

    # filter for tags
    #
    if ( lc($theTag) ne "all" ) {
        my @tags = split( /,/, $theTag );
        my @clauses;
        foreach my $t (@tags) {
            $t =~ s/^\s*//g;
            $t =~ s/\s*$//g;
            push @clauses, " t.item_name like '$t' ";
        }
        push @whereClauses, join( ' OR ', @clauses );
    }

    # filter for public
    if ( lc($thePublic) ne "all" ) {
        if ( lc($thePublic) eq "public" ) {
            push @whereClauses, "i2t.public=1";
        }
        elsif ( lc($thePublic) eq "private" ) {
            push @whereClauses, "i2t.public=0";
        }
        elsif ( lc($thePublic) eq "user" ) {

            my @membershipClauses = ();
            my $cuid = Foswiki::Plugins::TagsPlugin::Db::getUserID();
            push @membershipClauses, "i2t.user_id='$cuid'";

            # calculate group memberships
            my $it = Foswiki::Func::eachGroup();
            while ( $it->hasNext() ) {
                my $group = $it->next();
                if ( !Foswiki::Func::isGroupMember($group) ) { next; }
                my $group_id =
                  Foswiki::Plugins::TagsPlugin::Db::getUserID($group);
                Foswiki::Func::writeDebug("TAGSEARCH::groups: $group_id")
                  if DEBUG;
                if ($group_id) {
                    push @membershipClauses, "i2t.user_id='$group_id'";
                }
            }
            my $memberships = join( ' OR ', @membershipClauses );

            # construct the constraint
            if ( defined($cuid) ) {
                push @whereClauses,
                  "( (i2t.public=1) OR (i2t.public=0 AND ($memberships)) )";
            }
            else {
                push @whereClauses, "i2t.public=1";
            }

        }
    }

    # build the WHERE clause
    #
    push @whereClauses, " i.item_type = 'topic' ";
    my $where = join( ' AND ', @whereClauses );
    $where = 'WHERE ' . $where if ( $#whereClauses >= 0 );

    # build the GROUP BY clause
    #
    my %groupbyhash = ( "tag", 1, "topic", 1, "user", 1, "public", 1 );
    my @groupbyClauses = ();
    if ( $theFormat !~ m/\$(item|web|topic)/ ) { $groupbyhash{"topic"} = 0; }
    if ( $theFormat !~ m/\$(cuid|user)/ ) {
        $groupbyhash{"user"}   = 0;
        $groupbyhash{"public"} = 0;
    }
    if ( $theFormat !~ m/\$tag/ ) { $groupbyhash{"tag"} = 0; }
    while ( my ( $key, $value ) = each(%groupbyhash) ) {
        if ($value) { push @groupbyClauses, " $key " }
    }
    my $groupby = join( ',', @groupbyClauses );
    $groupby = "GROUP BY " . $groupby if ( $#groupbyClauses >= 0 );

    # build ORDER BY
    #
    my $order = "";
    if ( lc($theOrder) eq "tag" ) {
        $order = "ORDER BY t.item_name";
    }
    elsif ( lc($theOrder) eq "topic" ) {
        $order = "ORDER BY i.item_name";
    }
    elsif ( lc($theOrder) eq "user" ) {
        $order = "ORDER BY u.FoswikicUID";
    }

    # build LIMIT and OFFSET
    #
    my $limit = '';
    if ( $theLimit > 0 ) {
        $limit = "LIMIT $theLimit";
        if ( $theOffset > 0 ) {
            $limit .= " OFFSET $theOffset";
        }
    }

    # create the final SELECT statement
    #
    $statement = "
SELECT 
  t.item_name as tag, 
  i.item_name as topic,
  u.FoswikicUID as user,
  i2t.public as public,
  ts.num_items as count 
FROM Items t
INNER JOIN UserItemTag i2t ON i2t.tag_id=t.item_id 
INNER JOIN Items i ON i.item_id=i2t.item_id AND i.item_type='topic'
INNER JOIN TagStat ts ON t.item_id = ts.tag_id
INNER JOIN Users u ON i2t.user_id = u.CUID 
$where 
$groupby 
$order
$limit";

    Foswiki::Func::writeDebug("TAGSEARCH: $statement") if DEBUG;

    # get the data from the db and rotate through it
    my $row_counter = 0;
    my $arrayRef    = $db->dbSelect($statement);
    foreach my $row ( @{$arrayRef} ) {
        $row_counter++;
        my $entry = $theFormat;

        my $tag       = $row->[0];
        my $item      = $row->[1];
        my $cuid      = $row->[2];
        my $public    = $row->[3];
        my $tag_count = $row->[4];
        my $user      = Foswiki::Func::getWikiName($cuid);

        # replace all variable occurrences
        if ( $entry =~ m/\$(item|topic|web)/ ) {
            my ( $item_web, $item_topic ) =
              Foswiki::Func::normalizeWebTopicName( "", $item );
            $entry =~ s/\$item/$item/g;
            $entry =~ s/\$topic/$item_topic/g;
            $entry =~ s/\$web/$item_web/g;
        }

        if ( $entry =~ m/\$(cuid|user)/ ) {
            $entry =~ s/\$cuid/$cuid/g;
            $entry =~ s/\$user/$user/ge;
        }

        $entry =~ s/\$tag/$tag/g;
        $entry =~ s/\$count/$tag_count/g;
        $entry =~ s/\$num/$row_counter/g;
        $entry =~ s/\$public/$public/g;

        # flag this entry with "isAdmin" (useful for css classes)
        if ($isTagAdmin) {
            $entry =~ s/\$isAdmin/tagsplugin_isAdmin/gi;
        }
        else {
            $entry =~ s/\$isAdmin//gi;
        }

        # flag this entry as untaggable
        if (   $isTagAdmin
            || $cuid eq $session->{user}
            || Foswiki::Func::isGroupMember($cuid) )
        {
            $entry =~ s/\$untaggable/tagsplugin_untaggable/g;
        }
        else {
            $entry =~ s/\$untaggable//g;
        }

        # insert seperator only if needed
        if ( $output ne '' ) {
            $output .= $theSep . $entry;
        }
        else {
            $output = $entry;
        }
    }

    Foswiki::Func::writeDebug("row counter: $row_counter") if DEBUG;
    if ( $row_counter > 0 ) {
        $output = $theHeader . $output . $theFooter;    #if ($output);
    }
    else {
        $output = $theAlt;
    }

    # expand standard escapes
    $output =~ s/\$n/\n/g;
    $output =~ s/\$percnt/\%/g;
    $output =~ s/\$quot/"/g;
    $output =~ s/\$dollar/\$/g;

    # handle special renderings (ie. cloud)
    if ( $theRendering =~ /^cloud$/i && $row_counter > 0 ) {
        my $tml = "%TAGCLOUD{ terms=\"$output\" format=\"<a style='font-size:\$weightpx;' class='tagsplugin_tagcloud_tag' href='%SCRIPTURL{view}%/%SYSTEMWEB%/TagsPluginTagDetails?tag=\$term' item='\$3.\$4' topic='\$4' web='\$3' tag='\$term' user='\$5'>\$term</a>\" warn=\"off\" split=\"[,]+\" }%";
        $output = Foswiki::Func::expandCommonVariables( $tml, $topic, $web );
    }
    

    return $output;
}

1;
