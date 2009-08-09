# Module of Foswiki Enterprise Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2008, 2009 Sven Dowideit, SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::Store::TagsStore

adds a few extra layers to RcsWrap to implement the multi-user hosting options on wikiring.net

if you dont' have an active invite to a web, you can't see it - not access denied - does not exist..

and quota support.

=cut

package Foswiki::Store::TagsStore;
use base 'Foswiki::Store::RcsWrap';

use strict;
use Assert;

require Foswiki::Store;
require Foswiki::Sandbox;

# implements TagsStore
sub new {
    my( $class, $session, $web, $topic, $attachment ) = @_;

    my $key = join(', ', $web, ($topic||''), ($attachment||''));
    return $session->{handles}{$key} if defined($session->{handles}{$key});

    my $this = $class->SUPER::new( $session, $web, $topic, $attachment );
    $session->{handles}{$key} = $this;
#print STDERR "new(".$this->{web}.")(".($topic||'').")" unless defined($this->{attachment});
    return $this;
}

=pod

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
}

=pod

---++ ObjectMethod getWebNames() -> @webs

Gets a list of names of subwebs in the current web, by consulting the UserWebMap.

=cut

sub getWebNames {
    my $this = shift;
    return $this->SUPER::getWebNames(@_) unless (defined($Foswiki::cfg{TagsStore}{FilterByTags})
                                                && ($Foswiki::cfg{TagsStore}{FilterByTags} == 1));

    return () unless ($this->{web} eq '');

    #TODO: abstract this out so i don't litter s/^c// crap everywhere
    my $cuid = $this->{session}->{user};
    if ($this->{session}->{users}->isAdmin($cuid)) {
        $cuid = '333';
    }
    $cuid =~ s/^c//;

    use Foswiki::Contrib::DbiContrib;
    $this->{DB} = new Foswiki::Contrib::DbiContrib;
#TODO: this means that you can be a web owner but not be invited to see the web... could be useful?
    my $statement = sprintf("SELECT %s from %s WHERE %s = ?\n",  qw(RealWebName UserWebMap CUID));
    my $arrayRef = $this->{DB}->dbSelect($statement, $cuid);

    my @list = ('Home', $Foswiki::cfg{SystemWebName});
    foreach my $row (@{$arrayRef}) {
        push(@list, $row->[0]);
    }


    return @list;
}

=pod

---++ ObjectMethod getTopicNames() -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

   1 if ?tagfilter is not set then return all topics taged with the webname.
   2 if there is a ?tagfilter= then return topics taged with that.

=cut

sub getTopicNames {
    my $this = shift;

    return $this->SUPER::getTopicNames(@_) unless (defined($Foswiki::cfg{TagsStore}{FilterByTags})
                                                && ($Foswiki::cfg{TagsStore}{FilterByTags} == 1));

    my @tags = ($this->{web});
    my $tagSet = '('.join(',', map{"'$_'"} @tags).')';
    my $web = $this->{web};
    my $webLike = $web.'.%';

    my $db = new Foswiki::Contrib::DbiContrib;
    my $statement = "SELECT i.item_name
FROM UserItemTag i2t
INNER JOIN Items t ON i2t.tag_id = t.item_id
INNER JOIN Items i ON i2t.item_id = i.item_id
WHERE
i.item_name LIKE '$webLike' AND
i.item_type = 'topic' AND
t.item_name IN $tagSet
GROUP BY i2t.item_id;";

    my $arrayRef = $db->dbSelect($statement);
    my @topics;
    foreach my $row (@{$arrayRef}) {
        my $ItemName = $row->[0];

        $ItemName =~ s/^$web\.(.*)$/$1/e;

        push( @topics, $ItemName);
    }

    #print STDERR "db get TopicsNames(".$this->{web}."): ".scalar(@topics)."\n";
    return @topics;
}

=pod

---++ ObjectMethod storedDataExists() -> $boolean

Establishes if there is stored data associated with this handler.

=cut

sub storedDataExists {
    my $this = shift;
    if (-e $this->{file}) {
        return 1;
    }
    #check if {web} is a tag - and if so, is there are topic tagged with it?
    my $db = new Foswiki::Contrib::DbiContrib;
    my $originalWeb = $this->{web};

    my $item_id;
    my $statement = sprintf('SELECT %s from %s WHERE %s = ?',  qw( item_id Items item_name));
    my $arrayRef = $db->dbSelect($statement, $this->{web});
    if (defined($arrayRef->[0][0])) {
        my $tag_id = $arrayRef->[0][0];
        $statement = sprintf('SELECT %s from %s t INNER JOIN %s i ON %s = %s WHERE %s = ? AND %s LIKE ?',
                            qw(item_name UserItemTag Items t.item_id i.item_id tag_id item_name));
        $arrayRef = $db->dbSelect($statement, $tag_id, '%.'.$this->{topic});
        if (defined($arrayRef->[0][0])) {
            my $webTopic = $arrayRef->[0][0];
            ($this->{web}, $this->{topic}) = $this->{session}->normalizeWebTopicName($this->{web}, $webTopic);
            $this->resetFileName();
            $this->{web} = $originalWeb;
        } else {
            #if we didn't find the topic tagwise, then use the default ones.
            my %specialTopic = ('WebHome'=>1, 'WebPreferences'=>1, 'WebIndex'=>1, 'WebTopicList'=>1, 'WebChanges'=>1, 'WebSearch'=>1, 'WebRss'=>1, 'WebRssBase'=>1, 'WebLeftBar'=>1);
            if ($specialTopic{$this->{topic}}) {
                $this->{web} = '_tag';
                $this->resetFileName();
                $this->{web} = $originalWeb;
            }
        }
    }
    #print STDERR "storedDataExists(".$this->{web}.")(".$this->{topic}.")(".$this->{file}.")=>".((-e $this->{file})||0)."\n";

    return (-e $this->{file});
}

=pod

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use searchMetaData instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInWebContent {
    my( $this, $searchString, $topics, $options ) = @_;
    ASSERT(defined $options) if DEBUG;

    if ($options->{type} eq 'tag') {

        my @tags = split(/\s*,\s*/, $searchString);
        my $tagSet = '('.join(',', map{"'$_'"} @tags).')';
        my $web = $this->{web};
        my $webLike = $web.'.%';

        my $db = new Foswiki::Contrib::DbiContrib;
        my $statement = "SELECT i.item_name
FROM UserItemTag i2t
INNER JOIN Items t ON i2t.tag_id = t.item_id
INNER JOIN Items i ON i2t.item_id = i.item_id
WHERE
i.item_name LIKE '$webLike' AND
i.item_type = 'topic' AND
t.item_name IN $tagSet
GROUP BY i2t.item_id;";

        my $arrayRef = $db->dbSelect($statement);
        my %seen;
        foreach my $row (@{$arrayRef}) {
            my $ItemName = $row->[0];

            $ItemName =~ s/^$web\.(.*)$/$1/e;

            push( @{$seen{$ItemName}}, 'asd' );
        }
        return \%seen;
    } else {
        my $sDir = $Foswiki::cfg{DataDir}.'/'.$this->{web}.'/';

        unless ($this->{searchFn}) {
            eval "require $Foswiki::cfg{RCS}{SearchAlgorithm}";
            die "Bad {RCS}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@" if $@;
            $this->{searchFn} = $Foswiki::cfg{RCS}{SearchAlgorithm}.'::search';
        }        no strict 'refs';
        return &{$this->{searchFn}}($searchString, $topics, $options,
                   $sDir, $Foswiki::sandbox);
        use strict 'refs';
    }
}

################################################################################
#from Foswiki::Store::RcsFile::new
sub resetFileName {
    my $this = shift;

    if( $this->{topic} ) {
        my $rcsSubDir = ( $Foswiki::cfg{RCS}{useSubDir} ? '/RCS' : '' );
        if( $this->{attachment} ) {
            $this->{file} = $Foswiki::cfg{PubDir}.'/'.$this->{web}.'/'.
              $this->{topic}.'/'.$this->{attachment};
            $this->{rcsFile} = $Foswiki::cfg{PubDir}.'/'.
              $this->{web}.'/'.$this->{topic}.$rcsSubDir.'/'.$this->{attachment}.',v';

        } else {
            $this->{file} = $Foswiki::cfg{DataDir}.'/'.$this->{web}.'/'.
              $this->{topic}.'.txt';
            $this->{rcsFile} = $Foswiki::cfg{DataDir}.'/'.
              $this->{web}.$rcsSubDir.'/'.$this->{topic}.'.txt,v';
        }
    }
}

1;
