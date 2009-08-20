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

=begin TML

---++ do( $session, $params, $topic, $web )
Taghandler for TAGSEARCH.

Return:
 Formatted search result.
=cut

sub do {
    my ( $session, $params, $topic, $web ) = @_;

    my $theHeader = $params->{header}    || '';
    my $theSep    = $params->{separator} || $params->{sep} || ', ';
    my $theFooter = $params->{footer}    || '';
    my $theUser   = $params->{user}      || 'all';
    my $theWeb    = $params->{web}       || 'all';
    my $theTag    = $params->{tag}       || 'all';
    my $theTopic  = $params->{topic}     || '';
    my $theQuery  = $params->{query}     || 'tag'; 
    my $theFormat = $params->{format};
    
    # determine default format based on query type
    unless( $theFormat ) {
        if ( $theQuery eq "user" ) {
            $theFormat = '$user';
        } elsif ( $theQuery eq "topic" ) {
            $theFormat = '[[$item][$topic]]';
        } else {
            $theFormat = '$tag';
        };
    };
    
    my $isTagAdmin = Foswiki::Func::isGroupMember($Foswiki::cfg{TagsPlugin}{TagAdminGroup} || "AdminGroup") ? 1 : 0;
        
    my $output    = '';
    my $statement = '';
    my @whereClauses;

    my $db = new Foswiki::Contrib::DbiContrib;

    # resolve the cUID from the database and exit with "" if it does not exist
    #
    if (  lc($theUser) ne 'all' ) {
        my $cuid;
        my $statement =
          sprintf( 'SELECT %s from %s WHERE %s = ? ', qw( CUID Users FoswikicUID) );
        my $arrayRef = $db->dbSelect( $statement, Foswiki::Func::getCanonicalUserID( $theUser ) );
        if ( defined( $arrayRef->[0][0] ) ) {
            $cuid = $arrayRef->[0][0];
        }
        return '' unless ( defined($cuid) );
        push @whereClauses, " i2t.user_id = '$cuid' ";
    }

    # filter for webs
    #
    if ( $theWeb ne 'all' ) {
        my @webs = split( /,/, $theWeb );
        my @clauses;
        foreach my $w (@webs) {
            push @clauses, " i.item_name like '$w%' ";
        }
        push @whereClauses, join( ' OR ', @clauses );
    }    

    # filter for topics
    #
    if ( $theTopic ) {
        my @topics = split( /,/, $theTopic );
        my @clauses;
        foreach my $t (@topics) {
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
            push @clauses, " t.item_name like '$t' ";
        }
        push @whereClauses, join( ' OR ', @clauses );
    }

    # build the WHERE clause
    #
    push @whereClauses, " i.item_type = 'topic' ";
    my $where = join( ' AND ', @whereClauses );
    $where = 'WHERE ' . $where if ( $#whereClauses >= 0 );


    # build the GROUP BY clause
    #
    my %groupbyhash = ( "tag", 1, "topic", 1, "user", 1 );
    my @groupbyClauses = ();
    if ( $theFormat !~ m/\$(item|web|topic)/ ) { $groupbyhash{"topic"} = 0; };
    if ( $theFormat !~ m/\$(cuid|user)/      ) { $groupbyhash{"user"}  = 0; };
    if ( $theFormat !~ m/\$tag/              ) { $groupbyhash{"tag"}   = 0; };
    while( my ($key, $value) = each( %groupbyhash ) ) {
        if ( $value ) { push @groupbyClauses, " $key " };
    }
    my $groupby = join( ',', @groupbyClauses );
    $groupby = "GROUP BY " . $groupby if ( $#groupbyClauses >= 0 );

    # build ORDER BY
    #
    my $order = "";
    if ( lc($theQuery) eq "tag" ) {
        $order = "ORDER BY t.item_name";
    } elsif ( lc($theQuery) eq "topic" ) {
        $order = "ORDER BY i.item_name";
    } elsif ( lc($theQuery) eq "user" ) {
        $order = "ORDER BY u.FoswikicUID";
    }

    # create the final SELECT statement
    #
    $statement = "
SELECT 
  t.item_name as tag, 
  i.item_name as topic,
  u.FoswikicUID as user,
  ts.num_items as count 
FROM Items t
INNER JOIN UserItemTag i2t ON i2t.tag_id=t.item_id 
INNER JOIN Items i ON i.item_id=i2t.item_id AND i.item_type='topic'
INNER JOIN TagStat ts ON t.item_id = ts.tag_id
INNER JOIN Users u ON i2t.user_id = u.CUID 
$where 
$groupby 
$order";

    # Foswiki::Func::writeDebug("TAGSEARCH: $statement");

    # get the data from the db and rotate through it 
    my $arrayRef = $db->dbSelect($statement);
    foreach my $row ( @{$arrayRef} ) {
        my $entry = $theFormat;

        my $tag       = $row->[0];
        my $item      = $row->[1];
        my $cuid      = $row->[2];
        my $tag_count = $row->[3];

        # replace all variable occurrences
        if ( $entry =~ m/\$(item|topic|web)/ ) {
            my ($item_web, $item_topic) = Foswiki::Func::normalizeWebTopicName("", $item);
            $entry =~ s/\$item/$item/g;
            $entry =~ s/\$topic/$item_topic/g;
            $entry =~ s/\$web/$item_web/g;            
        }
            
        if ( $entry =~ m/\$(cuid|user)/ ) {
            $entry =~ s/\$cuid/$cuid/g;
            $entry =~ s/\$user/Foswiki::Func::getWikiName($cuid)/ge;                    
        }
        
        $entry =~ s/\$tag/$tag/g;
        $entry =~ s/\$count/$tag_count/g;
        
        # flag this entry as renameable (useful for css classes)
        if ( $isTagAdmin ) {
            $entry =~ s/\$renameable/tagsplugin_renameable/g;   
        } else {
            $entry =~ s/\$renameable//g;
        }
        
        # flag this entry as untaggable
        if ( $isTagAdmin || $cuid eq $session->{user} || Foswiki::Func::isGroupMember($cuid) ) {
            $entry =~ s/\$untaggable/tagsplugin_untaggable/g;   
        } else {
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

    $output = $theHeader . $output . $theFooter;

    # expand standard escapes
    $output =~ s/\$n/\n/g;
    $output =~ s/\$percnt/\%/g;
    $output =~ s/\$quot/"/g;
    $output =~ s/\$dollar/\$/g;

    return $output;
}

1;