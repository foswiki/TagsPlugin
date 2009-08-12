# Copyright 2008, 2009 SvenDowideit@fosiki.com
# distributed under GPL 3.

=pod

---+ package Foswiki::Plugins::TagsPlugin

=cut

package Foswiki::Plugins::TagsPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version
require Foswiki::Contrib::DbiContrib;

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $doneLoadTemplate );
$VERSION           = '$Rev$';
$RELEASE           = 'Foswiki-1.0.0';
$SHORTDESCRIPTION  = '  Full strength Tagging system ';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'TagsPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    my $setting = $Foswiki::cfg{Plugins}{TagsPlugin}{ExampleSetting} || 0;
    $debug = $Foswiki::cfg{Plugins}{TagsPlugin}{Debug} || 0;

    Foswiki::Func::registerTagHandler( 'TAGLIST',  \&_TAGLIST );
    Foswiki::Func::registerTagHandler( 'TAGENTRY', \&_TAGENTRY );
    Foswiki::Func::registerTagHandler( 'TAGCLOUD', \&_TAGCLOUD );

    Foswiki::Func::registerRESTHandler( 'tag',   \&tagCall );
    Foswiki::Func::registerRESTHandler( 'untag', \&untagCall );    

    #    Foswiki::Func::registerRESTHandler('updateGeoTags', \&updateGeoTags);

    Foswiki::Func::registerRESTHandler( 'initialiseDatabase',
        \&initialiseDatabase );

    #TODO: augment the IfParser and the QuerySearch Parsers to add Tags?

    #TODO: add a SEARCH{type="tags"} search type

    return 1;
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a Foswiki::Meta object

Makes sure any newly created topics get the 'Web' tag

=cut

sub afterSaveHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )")
      if $debug;

    updateTopicTags( 'topic', $_[2], $_[1],
        getUserId($Foswiki::Plugins::SESSION) );

    my $db = new Foswiki::Contrib::DbiContrib;
    $db->disconnect();    #force a commit

    return;
}

sub _loadTemplate {
    return if $doneLoadTemplate;
    $doneLoadTemplate = 1;

    Foswiki::Func::loadTemplate( lc($pluginName) );

#    my $header = Foswiki::Func::expandTemplate('twisty:header');
#    Foswiki::Func::addToHEAD( 'TWISTYPLUGIN_TWISTY', $header||'<!-- twisty:header not found in %SKIN% -->' );
    return;
}

sub _TAGLIST {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _loadTemplate();

    #TODO: need to limit it to taglist or tagcloud?
    my $displayType = lc( $params->{display} ) || 'taglist';
    my $header = $params->{header}
      || Foswiki::Func::expandTemplate(
        'tagsplugin:' . $displayType . ':header' )
      || '';
    my $format = $params->{format}
      || Foswiki::Func::expandTemplate(
        'tagsplugin:' . $displayType . ':format' )
      || '$tag';
    my $sep = $params->{separator}
      || Foswiki::Func::expandTemplate(
        'tagsplugin:' . $displayType . ':separator' )
      || ', ';
    my $footer = $params->{footer}
      || Foswiki::Func::expandTemplate(
        'tagsplugin:' . $displayType . ':footer' )
      || '';

    my @whereClauses;
    my @joinsClauses;

    my $showUser = $params->{show};
    if ( !defined($showUser) || ( lc($showUser) ne 'user' ) ) {
    }
    else {
        my $user_id = getUserId($session);
        return '' unless ( defined($user_id) );
        push @whereClauses, " i2t.user_id = '$user_id' ";
    }
    my $showType = $params->{type};
    if ( defined($showType) && $showType ne '' ) {
        push @whereClauses, " i.item_type = '$showType' ";
    }

    my $ItemName = $params->{item};
    if ( defined($ItemName) && $ItemName ne '' ) {
        push @whereClauses, " i.item_name = '$ItemName' ";
    }

#filter by (show only tags that are tagged with this tag - ie, show the country tags on the requested Item)
#TODO: !filters don't work properly, as it will only list tags that are tagged with another tag - most are not.
    my $filter = $params->{filter};
    if ( defined($filter) && $filter ne '' ) {
        push @joinsClauses,
          " INNER JOIN UserItemTag fi2t ON fi2t.item_id = i2t.tag_id ";
        push @joinsClauses, " INNER JOIN Items f ON fi2t.tag_id = f.item_id ";
        my @filters = split( /,/, $filter );
        my @clauses;
        foreach my $f (@filters) {
            my $eq = '=';
            if ( $f =~ /^!(.*)/ ) {
                $f  = $1;
                $eq = '!=';
            }
            push @clauses, " f.item_name $eq '$f' ";
        }
        push @whereClauses, join( ' OR ', @clauses );

    }

    my $retreiveNameFrom = 't';

#this inverts the query (ie, list tags that topics that are taged with this tag are also tagged by)
    my $TagName = $params->{tag};
    if ( defined($TagName) && $TagName ne '' ) {
        push @whereClauses, " t.item_name = '$TagName' ";
        $retreiveNameFrom = 'i';
    }

    #hide the hidden tags (those starting with _). (same syntax as WebNames..)
    my $showhidden = $params->{showhidden};
    if ( defined($showhidden) && $showhidden ne '' ) {
    }
    else {
        push @whereClauses, " NOT $retreiveNameFrom.item_name LIKE '\\_\%' ";
    }

    my $where = join( ' AND ', @whereClauses );
    $where = 'WHERE ' . $where if ( $#whereClauses >= 0 );

    my $joins = join( "\n", @joinsClauses );

    my $output = '';

    my $db = new Foswiki::Contrib::DbiContrib;
    my $statement =
      "SELECT $retreiveNameFrom.item_name, ts.num_items FROM UserItemTag i2t
INNER JOIN Items t ON t.item_type = 'tag' AND i2t.tag_id = t.item_id
INNER JOIN TagStat ts ON t.item_id = ts.tag_id
INNER JOIN Items i ON i2t.item_id = i.item_id
$joins
$where
GROUP BY $retreiveNameFrom.item_name;
";

    #print STDERR "$statement";

    my $arrayRef = $db->dbSelect($statement);
    my @list;
    foreach my $row ( @{$arrayRef} ) {
        my $tag        = $row->[0];
        my $escapedTag = Foswiki::urlEncode($tag);
        $escapedTag =~ s/\s/\+/g;
        my $tagurl =
            '%SCRIPTURL{view}%/%SYSTEMWEB%/'
          . $pluginName
          . 'Views?tag='
          . $escapedTag;
        my $tag_count = $row->[1];

        my $entry = $format;
        $entry =~ s/\$tagrange/not-popular/g
          ; #TODO: from (not-popular not-very-popular somewhat-popular popular very-popular ultra-popular)
        $entry =~ s/\$tagurl/$tagurl/g;
        $entry =~ s/\$tag/$tag/g;
        $entry =~ s/\$count/$tag_count/g;
        if ( $output ne '' ) {
            $output = $output . $sep . $entry;
        }
        else {
            $output = $entry;
        }
    }

    $output = $header . $output . $footer;
    $output =~ s/\$n/\n/g;
    $output =~ s/\$percnt/\%/g;
    $output =~ s/\$quot/"/g;
    $output =~ s/\$dollar/\$/g;

    return $output;
}

sub _TAGENTRY {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    return '' if ( Foswiki::Func::isGuest() );

    _loadTemplate();
    my $template = Foswiki::Func::expandTemplate('tagsplugin:tagentry');
    return $template;
}

sub _TAGCLOUD {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    $params->{display} = 'tagcloud';
    return _TAGLIST( $session, $params, $theTopic, $theWeb );
}

=pod

---++ tagCall($session) -> $text

Add new tag: (aparently SELECT then INSERT is faster than REPLACE)
   1 if 'item' not in Items table
      * INSERT INTO Items (item_name, item_type) VALUES ("$web.$name", 'topic');
   2 $item_id = SELECT item_id FROM Items WHERE item_name = "$web.$name" AND item_type = 'topic';
   3 if 'tag' not in Tags table
      * INSERT INTO Tags (t.item_name) VALUES ($tag);
   4 $tag_id = SELECT tag_id FROM Tags WHERE t.item_name = $tag;
   5 INSERT INTO UserItemTag (user_id, item_id, tag_id) VALUES($user_id, $item_id, $tag_id);
   6 increment counters
      * UPDATE TagStat SET num_items=num_items+1 WHERE  tag_id = $tag_id
      * UPDATE UserTagStat SET num_items=num_items+1 WHERE  tag_id = $tag_id AND user_id = $user_id


=cut

sub tagCall {
    my ($session) = @_;
    my $query = Foswiki::Func::getCgiQuery();

    my $item_name  = $query->param('item');
    my $item_type  = $query->param('type') || 'topic';
    my $tag_text   = $query->param('tag');
    my $redirectto = $query->param('redirectto');

    $item_name = Foswiki::Sandbox::untaintUnchecked($item_name);
    $item_type = Foswiki::Sandbox::untaintUnchecked($item_type);
    $tag_text  = Foswiki::Sandbox::untaintUnchecked($tag_text);

    my $user_id = getUserId($session);
    tagItem( $item_type, $item_name, $tag_text, $user_id );

    my $db = new Foswiki::Contrib::DbiContrib;
    $db->disconnect();    #force a commit

    my $toUrl = '';
    if ( defined($redirectto) ) {
        $toUrl = $redirectto;
    }
    else {
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( '', $item_name );
        $toUrl = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );
    }
    Foswiki::Func::redirectCgiQuery( undef, $toUrl );
}

sub untagCall {
    use Foswiki::Plugins::TagsPlugin::Untag;
    return Foswiki::Plugins::TagsPlugin::Untag::rest( @_ );    
}

sub getUserId {
    my $session = shift;

    my $FoswikiCuid = $session->{user};

  #    if ($session->{users}->isAdmin($FoswikiCuid)) {
  #        $FoswikiCuid = '333';
  #    }
  #    $FoswikiCuid =~ s/^c//;
  #    $FoswikiCuid = '666' if (!defined($FoswikiCuid) || ($FoswikiCuid eq ''));
  #    #TODO: possibly show Guest the stats for Home web?
  #    $FoswikiCuid = '666' if ($FoswikiCuid =~ /BaseUserMapping_/);

    my $db = new Foswiki::Contrib::DbiContrib;
    my $cuid;
    my $statement =
      sprintf( 'SELECT %s from %s WHERE %s = ? ', qw( CUID Users FoswikicUID) );
    my $arrayRef = $db->dbSelect( $statement, $FoswikiCuid );
    if ( defined( $arrayRef->[0][0] ) ) {
        $cuid = $arrayRef->[0][0];
    }
    else {
        $statement =
          sprintf( 'INSERT INTO %s (%s) VALUES (?)', qw(Users FoswikicUID) );
        my $rowCount = $db->dbInsert( $statement, $FoswikiCuid );
        my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? ',
            qw( CUID Users FoswikicUID) );
        $arrayRef = $db->dbSelect( $statement, $FoswikiCuid );
        $cuid = $arrayRef->[0][0];
    }

    return $cuid;
}

=pod

--+++ updateTopicTags($item_type, $web, $topic, $user_id)
update the tags for this topic

#TODO: remove formname tags if the form is changed..
#TODO: remove category tags if they are removed from topic text..

=cut

sub updateTopicTags {
    my ( $item_type, $web, $topic, $user_id ) = @_;
    my $session = $Foswiki::Plugins::SESSION;

    tagItem( $item_type, "$web.$topic", $web, $user_id );

    my ( $meta, $text );
    if ( $Foswiki::cfg{TagsPlugin}{EnableDataForms} || $Foswiki::cfg{TagsPlugin}{EnableCategories} ) {
        ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );        
    }
    
    if ( defined($Foswiki::cfg{TagsPlugin}{EnableCategories}) && $Foswiki::cfg{TagsPlugin}{EnableCategories} ) {
        #open the topic, find WikiWords ending in Category, and add that as a tag.
        my $alpha = Foswiki::Func::getRegularExpression('mixedAlphaNum');
        #my $capitalized = qr/[$upper][$alpha]+/;
        $text =~
          s/[;,\s]([$alpha]*)Category[;,\s]/tagItem($item_type, "$web.$topic", $1, $user_id);tagItem('tag', $1, $web, $user_id);''/geo;
    }

    if ( defined($Foswiki::cfg{TagsPlugin}{EnableDataForms}) && $Foswiki::cfg{TagsPlugin}{EnableDataForms} ) {
        #add formname as tag - if present
        my $formName = $meta->getFormName();
        if ( $formName ne '' ) {
            tagItem( $item_type, "$web.$topic", $formName, $user_id );    
            #TODO: tag that tag with FormName..
        }
    }
    return;
}

#TODO: if you use item_type='tag' I think it needs to create the tagstat for that too
sub tagItem {
    my ( $item_type, $item_name, $tag_text, $user_id ) = @_;

    return unless ( ( defined($tag_text) )  && ( $tag_text  ne '' ) );
    return unless ( ( defined($item_name) ) && ( $item_name ne '' ) );

    my $db = new Foswiki::Contrib::DbiContrib;
    my $item_id;
    my $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    my $arrayRef = $db->dbSelect( $statement, $item_name, $item_type );
    if ( defined( $arrayRef->[0][0] ) ) {
        $item_id = $arrayRef->[0][0];
    }
    else {
        $statement = sprintf( 'INSERT INTO %s (%s, %s) VALUES (?,?)',
            qw( Items item_name item_type) );
        my $rowCount = $db->dbInsert( $statement, $item_name, $item_type );
        $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
            qw( item_id Items item_name item_type) );
        $arrayRef = $db->dbSelect( $statement, $item_name, $item_type );
        $item_id = $arrayRef->[0][0];
    }

    my $tag_id;
    my $new_tag = 0;
    $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
        qw( item_id Items item_name item_type) );
    $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }
    else {
        $statement = sprintf( 'INSERT INTO %s (%s,%s) VALUES (?,?)',
            qw(Items item_name item_type) );
        my $rowCount = $db->dbInsert( $statement, $tag_text, 'tag' );
        $statement = sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ?',
            qw(item_id Items item_name item_type) );
        $arrayRef = $db->dbSelect( $statement, $tag_text, 'tag' );
        $tag_id = $arrayRef->[0][0];

        $statement =
          sprintf( 'INSERT INTO %s (%s) VALUES (?)', qw( TagStat tag_id) );
        $db->dbInsert( $statement, $tag_id );
        $statement = sprintf( 'INSERT INTO %s (%s,%s) VALUES (?,?)',
            qw( UserTagStat tag_id user_id) );
        $db->dbInsert( $statement, $tag_id, $user_id );
        $new_tag = 1;
    }

    my $rowCount = 0;
    $statement =
      sprintf( 'SELECT %s from %s WHERE %s = ? AND %s = ? AND %s = ?',
        qw(tag_id UserItemTag user_id item_id tag_id) );
    $arrayRef = $db->dbSelect( $statement, $user_id, $item_id, $tag_id );
    if ( !defined( $arrayRef->[0][0] ) ) {
        $statement = sprintf( 'INSERT INTO %s (%s, %s, %s) VALUES (?,?,?)',
            qw( UserItemTag user_id item_id tag_id) );
        $rowCount = $db->dbInsert( $statement, $user_id, $item_id, $tag_id );

        unless ($new_tag) {
            $statement = sprintf( 'UPDATE %s SET %s=%s+1 WHERE %s = ?',
                qw( TagStat num_items num_items tag_id) );
            my $modified = $db->dbInsert( $statement, $tag_id );
            if ( $modified == 0 ) {
                $statement = sprintf( 'INSERT INTO %s (%s) VALUES (?)',
                    qw( TagStat tag_id) );
                $db->dbInsert( $statement, $tag_id );
            }
            $statement =
              sprintf( 'UPDATE %s SET %s=%s+1 WHERE %s = ? AND %s = ?',
                qw( UserTagStat num_items num_items tag_id user_id) );
            $modified = $db->dbInsert( $statement, $tag_id, $user_id );
            if ( $modified == 0 ) {
                $statement = sprintf( 'INSERT INTO %s (%s,%s) VALUES (?,?)',
                    qw( UserTagStat tag_id user_id) );
                $db->dbInsert( $statement, $tag_id, $user_id );
            }
        }
    }
    
    # flushing the changes
    $db->commit();

    return $rowCount;
}

sub initialiseDatabase {
    my ($session) = @_;

    #my $query = Foswiki::Func::getCgiQuery();

#use the traditional file based view of webs and topics, so that we actually give them all tags
    undef $Foswiki::cfg{WikiRingNetStore}{FilterByTags};

    #TODO: if the database tables are not there, create them
    my $db        = new Foswiki::Contrib::DbiContrib;
    my $statement = <<'END';
CREATE TABLE IF NOT EXISTS `Items` (
  `item_id` int(10) unsigned NOT NULL auto_increment,
  `item_name` varchar(255) NOT NULL,
  `item_type` enum('topic','tag','user','url','web') NOT NULL default 'topic',
  PRIMARY KEY  (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=904 DEFAULT CHARSET=latin1;
END
    my $arrayRef = $db->dbInsert($statement);

    $statement = <<'END';
CREATE TABLE IF NOT EXISTS  `Users` (
  `FoswikicUID` varchar(256) character set ascii NOT NULL,
  `CUID` int(10) unsigned NOT NULL auto_increment,
  PRIMARY KEY  USING BTREE (`CUID`),
  KEY `emails_unique` (`FoswikicUID`)
) ENGINE=InnoDB AUTO_INCREMENT=23461 DEFAULT CHARSET=latin1;
END
    $arrayRef = $db->dbInsert($statement);

    $statement = <<'END';
CREATE TABLE IF NOT EXISTS  `TagStat` (
  `tag_id` int(10) unsigned NOT NULL auto_increment,
  `num_items` int(10) unsigned NOT NULL default '1',
  PRIMARY KEY  (`tag_id`),
  CONSTRAINT `TagStat_ibfk_1` FOREIGN KEY (`tag_id`) REFERENCES `Items` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=latin1;
END
    $arrayRef = $db->dbInsert($statement);

    $statement = <<'END';
CREATE TABLE IF NOT EXISTS `UserItemTag`  (
  `user_id` int(10) unsigned NOT NULL,
  `item_id` int(10) unsigned NOT NULL,
  `tag_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`user_id`,`item_id`,`tag_id`),
  KEY `item_id` (`item_id`),
  KEY `tag_id` (`tag_id`),
  CONSTRAINT `UserItemTag_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `Users` (`CUID`),
  CONSTRAINT `UserItemTag_ibfk_2` FOREIGN KEY (`item_id`) REFERENCES `Items` (`item_id`),
  CONSTRAINT `UserItemTag_ibfk_3` FOREIGN KEY (`tag_id`) REFERENCES `Items` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END
    $arrayRef = $db->dbInsert($statement);

    $statement = <<'END';
CREATE TABLE IF NOT EXISTS  `UserTagStat` (
  `user_id` int(10) unsigned NOT NULL,
  `tag_id` int(10) unsigned NOT NULL auto_increment,
  `num_items` int(10) unsigned NOT NULL default '1',
  PRIMARY KEY  (`user_id`,`tag_id`),
  KEY `fk_Tag` (`tag_id`),
  CONSTRAINT `UserTagStat_ibfk_1` FOREIGN KEY (`tag_id`) REFERENCES `Items` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=latin1;
END
    $arrayRef = $db->dbInsert($statement);

    #add basic tags
    # - each topic is tagged with the web its in (tag type?)
    # - import TagMe tags
    my $count   = 0;
    my $user_id = getUserId($session);
    my @weblist = Foswiki::Func::getListOfWebs();
    foreach my $web (@weblist) {
        my @topiclist = Foswiki::Func::getTopicList($web);
        foreach my $topic (@topiclist) {
            updateTopicTags( 'topic', $web, $topic, $user_id );
            $count++;
        }
        tagItem( 'tag', $web, 'web', $user_id );
    }

    #my $db = new Foswiki::Contrib::DbiContrib;
    $db->disconnect();    #force a commit

    return 'ok ' . $count;
}

1;
