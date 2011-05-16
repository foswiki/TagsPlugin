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
require Foswiki::Plugins::TagsPlugin::Db;
require Foswiki::Plugins::TagsPlugin::Func;

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $doneLoadTemplate %doneLoadJS );
$VERSION           = '$Rev$';
$RELEASE           = 'Foswiki-1.0.0';
$SHORTDESCRIPTION  = 'Full strength Tagging system ';
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

    # check db_schema_version
    my $workArea = Foswiki::Func::getWorkArea($pluginName);
    if ( $workArea !~ m/.*\/$/ ) {
        $workArea .= "/";
    }
    if ( Foswiki::Func::readFile( $workArea . "db_schema_version.txt" ) !~
        m/^1\.1$/ )
    {
        Foswiki::Func::writeWarning(
            "DB schema Version mismatch. Please convert your database.");

#TODO: need a more correct error for NO DB INITIALISED yet
#need to allow the user to init, or update the db - so the plugin needs to succeed..
    Foswiki::Func::registerRESTHandler( 'initialiseDatabase',
        \&initialiseDatabase );
    Foswiki::Func::registerRESTHandler( 'convertDatabase', \&convertDatabase );
        return 1;
    }

    Foswiki::Func::registerTagHandler( 'TAGLIST',  \&_TAGLIST );
    Foswiki::Func::registerTagHandler( 'TAGENTRY', \&_TAGENTRY );
    Foswiki::Func::registerTagHandler( 'TAGCLOUD', \&_TAGCLOUD )
      if ( defined( $Foswiki::cfg{TagsPlugin}{EnableTagCloud} )
        && $Foswiki::cfg{TagsPlugin}{EnableTagCloud} );
    Foswiki::Func::registerTagHandler( 'TAGCLOUDCLICK', \&_TAGCLOUDCLICK );
    Foswiki::Func::registerTagHandler( 'TAGSEARCH',     \&_TAGSEARCH );
    Foswiki::Func::registerTagHandler( 'TAGGROUPS',     \&_TAGGROUPS );
    Foswiki::Func::registerTagHandler( 'ISTAGADMIN',    \&_ISTAGADMIN );
    Foswiki::Func::registerTagHandler( 'TAGREQUIRE',    \&_TAGREQUIRE );

    Foswiki::Func::registerRESTHandler( 'tag',         \&tagCall );
    Foswiki::Func::registerRESTHandler( 'untag',       \&untagCall );
    Foswiki::Func::registerRESTHandler( 'public',      \&publicCall );
    Foswiki::Func::registerRESTHandler( 'changeOwner', \&changeOwnerCall );
    Foswiki::Func::registerRESTHandler( 'delete',      \&deleteCall );
    Foswiki::Func::registerRESTHandler( 'rename',      \&renameCall );
    Foswiki::Func::registerRESTHandler( 'merge',       \&mergeCall );
    Foswiki::Func::registerRESTHandler( 'initialiseDatabase',
        \&initialiseDatabase );
    Foswiki::Func::registerRESTHandler( 'convertDatabase', \&convertDatabase );
    Foswiki::Func::registerRESTHandler( 'importTagMe',     \&importTagMe );

    #Foswiki::Func::registerRESTHandler('updateGeoTags', \&updateGeoTags);

    # TODO: augment the IfParser and the QuerySearch Parsers to add Tags?
    # TODO: add a SEARCH{type="tags"} search type

    # load some js and css in the header
    # plus add some data through meta tags
    my $tagweb   = Foswiki::Func::getPreferencesValue("TAGWEB")   || $web;
    my $tagtopic = Foswiki::Func::getPreferencesValue("TAGTOPIC") || $topic;
    my $header =
'<meta name="foswiki.tagsplugin.defaultuser" content="%TAGSPLUGIN_TAGUSER%" />'
      . "\n";
    $header .=
      '<meta name="foswiki.tagsplugin.web" content="' . $tagweb . '" />' . "\n";
    $header .= '<meta name="foswiki.tagsplugin.topic" content="'
      . $tagtopic . '" />' . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Ok" content="%MAKETEXT{"Ok"}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.NothingChanged" content="%MAKETEXT{"Nothing changed."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.TagDetailsOn" content="%MAKETEXT{"Tag Details on"}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Tag400" content="%MAKETEXT{"Assuming you are logged-in and assuming you provided a tag name you probably just revealed a software bug. I am sorry about that. (400)"}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Tag401" content="%MAKETEXT{"According to my data, you are not logged in. Please log-in before you retry."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Tag403" content="%MAKETEXT{"I am sorry, but you are not allowed to do that."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Tag500" content="%MAKETEXT{"Something beyond your sphere of influence went wrong. Most probably a problem with the database. May I kindly ask you to inform your administrator? Thank you."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.TagUnknown" content="%MAKETEXT{"Unknown error in tagsplugin_be_tag."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Untag400" content="%MAKETEXT{"Assuming you are logged in you probably just revealed a software bug. I am sorry about that. (400)"}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Untag401" content="%MAKETEXT{"According to my data, you are not logged in. Please log-in before you retry."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Untag403" content="%MAKETEXT{"I am sorry, but you are not allowed to do that."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Untag404" content="%MAKETEXT{"I am sorry, but either the tag or the topic does not exist."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Untag500" content="%MAKETEXT{"Something beyond your sphere of influence went wrong. Most probably a problem with the database. May I kindly ask you to inform your administrator? Thank you."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.UntagUnknown" content="%MAKETEXT{"Unknown error in tagsplugin_be_untag."}%" />'
      . "\n";
    $header .=
'<meta name="foswiki.tagsplugin.translation.Attention" content="%MAKETEXT{"May I kindly ask for your attention?"}%" />'
      . "\n";
    $header .=
'<link rel="stylesheet" type="text/css" href="%PUBURL%/System/TagsPlugin/tagsplugin.css" media="all" />'
      . "\n";
    Foswiki::Func::addToHEAD( 'TAGSPLUGIN', "\n" . $header );

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
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )")
      if $debug;

    updateTopicTags( 'topic', $_[2], $_[1],
        Foswiki::Plugins::TagsPlugin::Db::createUserID() );

    my $db = new Foswiki::Contrib::DbiContrib;
    $db->disconnect();    #force a commit

    return;
}

sub afterRenameHandler {
    my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic,
        $newAttachment ) = @_;

    # ignore attachment renamings
    # TODO: we should not ignore web renamings
    if ( $oldTopic && $newTopic ) {
        my $oldLocation = "$oldWeb.$oldTopic";
        my $newLocation = "$newWeb.$newTopic";

        my $db        = new Foswiki::Contrib::DbiContrib;
        my $statement = sprintf( 'UPDATE %s SET %s = ? WHERE %s = ? AND %s = ?',
            qw(Items item_name item_name item_type) );
        my $rowCount =
          $db->dbInsert( $statement, $newLocation, $oldLocation, "topic" );
        $db->disconnect();
        Foswiki::Func::writeDebug(
"- ${pluginName}::afterSaveHandler( SQL: $statement, $newLocation, $oldLocation, topic -> $rowCount )"
        );
    }

    return "";
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
        my $user_id = Foswiki::Plugins::TagsPlugin::Db::createUserID();
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
    my $template;
    return '' if ( Foswiki::Func::isGuest() );

    _loadTemplate();

    if ( Foswiki::Func::getSkin() =~ m/tagspluginjquery/ ) {
        $template = Foswiki::Func::expandTemplate('tagsplugin:jquery:taginput');
    }
    else {
        $template = Foswiki::Func::expandTemplate('tagsplugin:tagentry');
    }
    return $template;
}

sub _TAGCLOUD {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    $params->{display} = 'tagcloud';
    return _TAGLIST( $session, $params, $theTopic, $theWeb );
}

sub _TAGCLOUDCLICK {
    use Foswiki::Plugins::TagsPlugin::TAGCLOUDCLICK;
    return Foswiki::Plugins::TagsPlugin::TAGCLOUDCLICK::do(@_);
}

sub _TAGSEARCH {
    use Foswiki::Plugins::TagsPlugin::TAGSEARCH;
    return Foswiki::Plugins::TagsPlugin::TAGSEARCH::do(@_);
}

sub _TAGGROUPS {
    use Foswiki::Plugins::TagsPlugin::TAGGROUPS;
    return Foswiki::Plugins::TagsPlugin::TAGGROUPS::do(@_);
}

sub _ISTAGADMIN {
    my $tagAdminGroup = $Foswiki::cfg{TagsPlugin}{TagAdminGroup}
      || "AdminGroup";
    if (
        !Foswiki::Func::isGroupMember(
            $tagAdminGroup, Foswiki::Func::getWikiName()
        )
      )
    {
        return "0";
    }
    else {
        return "1";
    }
}

sub _TAGREQUIRE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $what = lc( $params->{"_DEFAULT"} || "" );

    if ( $what eq "" || $doneLoadJS{$what} ) {
        return "";
    }
    else {
        my $js = "\n"
          . '<script type="text/javascript" src="'
          . $Foswiki::cfg{PubUrlPath}
          . '/System/TagsPlugin/tagsplugin-'
          . $what
          . '.js"></script>';
        Foswiki::Func::addToHEAD( "TAGSPLUGIN::" . uc($what), $js );
        return "";
    }
}

=pod

---++ tagCall($session) -> $text

This is the REST wrapper for tag.

Takes the following url parameters:
 item       : name of the topic to be tagged (format: Sandbox.TestTopic)
 type       : either "topic" or "tag", defaults to "topic"
 tag        : name of the tag
 user       : (optional) Wikiname of the user or group, whose tag shall be deleted (format: JoeDoe)
 redirectto : (optional) redirect target after action is performed

If "user" is a groupname, the currently logged in user has to be member of that group. 

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing or empty
 401 : access denied for unauthorized user
 403 : the user is not allowed to tag 

Return:
In case of an error (!=200 ) just the status code incl. short description is returned.
Otherwise a 200 is returned or if requested a redirect is performed.

TODO:
 force http POST method
 if you use item_type='tag' I think it needs to create the tagstat for that too 

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
    use Foswiki::Plugins::TagsPlugin::Tag;
    return Foswiki::Plugins::TagsPlugin::Tag::rest(@_);
}

=begin TML

---++ untagCall($session) -> $text
This is the REST wrapper for untag.

Takes the following url parameters:
 item   : name of the topic to be untagged (format: Sandbox.TestTopic)
 tag    : name of the tag
 user   : (optional) Wikiname of the user or group, whose tag shall be deleted (format: JoeDoe) 
 public : 0 or 1

If "user" is a groupname, the currently logged in user has to be member of that group. 

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing
 401 : access denied for unauthorized user
 403 : the user is not allowed to untag 
 404 : tag or item not found
 500 : misc database errors

Return:
In case of an error (!=200 ) just the status code incl. short description is returned.
Otherwise a 200 and the number of affected tags (usually 0 or 1) is returned.

TODO:
 force http POST method

=cut

sub untagCall {
    use Foswiki::Plugins::TagsPlugin::Untag;
    return Foswiki::Plugins::TagsPlugin::Untag::rest(@_);
}

=pod

---++ publicCall($session) -> $text

This is the REST wrapper for public.

Takes the following url parameters:
 item       : name of the topic (format: Sandbox.TestTopic)
 tag        : name of the tag
 user       : (Optional) Wikiname of the user or group (format: JoeDoe), defaults to current user
 public     : (Optional) Sets or unsets the public flag (values: "0" or "1")

If "user" is a groupname, the currently logged in user has to be member of that group. 

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing or empty
 401 : access denied for unauthorized user
 403 : the user is not allowed to to change the public flag 

Return:
In case of an error (!=200 ) just the status code incl. short description is returned.
Otherwise a 200 is returned.

TODO:
 force http POST method

Sets public flag for a given topic/tag/user tupel. Quits silently if nothing to do.
      
=cut

sub publicCall {
    use Foswiki::Plugins::TagsPlugin::Public;
    return Foswiki::Plugins::TagsPlugin::Public::rest(@_);
}

=pod

---++ changeOwnerCall($session) -> $text

This is the REST wrapper for changing the owner of a tag.

Takes the following url parameters:
 item       : name of the topic (format: Sandbox.TestTopic)
 tag        : name of the tag
 public     : public status (values: "0" or "1")
 user       : (Optional) Wikiname of the user or group (format: JoeDoe), defaults to current user
 newuser    : (Optional) Wikiname of the user or group (format: JoeDoe), defaults to current user

If "user" is a groupname, the currently logged in user has to be member of that group. 

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing or empty
 401 : access denied for unauthorized user
 403 : the user is not allowed to to change the tag 

Return:
In case of an error (!=200 ) just the status code incl. short description is returned.
Otherwise a 200 is returned.

TODO:
 force http POST method

Sets a new owner for a given topic/tag/user/public tupel. Quits silently if nothing to do.
      
=cut

sub changeOwnerCall {
    use Foswiki::Plugins::TagsPlugin::ChangeOwner;
    return Foswiki::Plugins::TagsPlugin::ChangeOwner::rest(@_);
}

=begin TML

---++ deleteCall( $session )
This is the REST wrapper for delete.

Delete purges the given tag and all its instances from the database.

Takes the following url parameters:
 tag  : name of the tag

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing
 403 : the user is not allowed to delete tags 
 404 : tag not found

Return:
In case of an error (!=200 ) just the status code incl. short description is returned.
Otherwise a 200 and the number of affected tags (usually 0 or 1) is returned.

TODO:
 force http POST method

=cut

sub deleteCall {
    use Foswiki::Plugins::TagsPlugin::Delete;
    return Foswiki::Plugins::TagsPlugin::Delete::rest(@_);
}

=begin TML

---++ renameCall( $session )
This is the REST wrapper for rename.

Takes the following url parameters:
 oldtag : name of the tag to be renamed
 newtag : new name for the old tag

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing
 403 : the user is not allowed to rename 
 404 : oldtag not found
 409 : newtag already exists
 500 : database error

Return:
In case of an error (!=200) just the status code incl. short description is returned.
Otherwise a 200 and the number of affected tags (usually 0 or 1) is returned.

TODO:
 force http POST method

=cut

sub renameCall {
    use Foswiki::Plugins::TagsPlugin::Rename;
    return Foswiki::Plugins::TagsPlugin::Rename::rest(@_);
}

=begin TML

---++ mergeCall( $session )
This is the REST wrapper for merge.

Takes the following url parameters:
 tag1 : name of the tag to be renamed
 tag2 : new name for the old tag

It checks the prerequisites and sets the following status codes:
 200 : Ok
 400 : url parameter(s) are missing
 403 : the user is not allowed to merge 
 404 : either tag1 or tag2 not found
 500 : misc database errors

Return:
In case of an error (!=200) just the status code incl. short description is returned.
Otherwise a 200 and the number is returned (0 indicates an update error, any positive number is fine).

TODO:
 force http POST method
 
=cut

sub mergeCall {
    use Foswiki::Plugins::TagsPlugin::Merge;
    return Foswiki::Plugins::TagsPlugin::Merge::rest(@_);
}

=begin TML

--+++ updateTopicTags($item_type, $web, $topic, $user_id)
Update some (automatic) tags for the given topic.

Parameters:
 item_type : currently either "tag" or "topic"; see note below
 web       : webname of the topic to be updated
 topic     : topicname of the topic to be updated
 user_id   : a wikiname (ie. JohnDoe ) of a user or group, who the (new) tags shall belong to.

If enabled by {EnableWebTags} this topic is tagged with a tag named after the web (!AdminUser as owner).
If enabled by {EnableDataForms} and a =<nop>FooForm= is attached to the topic, it is tagged with the =<nop>FooForm=.
If enabled by {EnableCategories}, the topic is tagged with =Foo= for each link to a =<nop>FooCategory= in the topic text. 

#TODO: remove formname tags if the form is changed.
#TODO: remove category tags if they are removed from topic text.

=cut

sub updateTopicTags {
    my ( $item_type, $web, $topic, $user_id ) = @_;

    use Foswiki::Plugins::TagsPlugin::Tag;

    if ( defined( $Foswiki::cfg{TagsPlugin}{EnableWebTags} )
        && $Foswiki::cfg{TagsPlugin}{EnableWebTags} )
    {
        Foswiki::Plugins::TagsPlugin::Tag::do( $item_type, "$web.$topic", $web,
            Foswiki::Func::getCanonicalUserID("AdminUser") );
    }

    my ( $meta, $text );
    if (   $Foswiki::cfg{TagsPlugin}{EnableDataForms}
        || $Foswiki::cfg{TagsPlugin}{EnableCategories} )
    {
        ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    }

    if ( defined( $Foswiki::cfg{TagsPlugin}{EnableCategories} )
        && $Foswiki::cfg{TagsPlugin}{EnableCategories} )
    {

      #open the topic, find WikiWords ending in Category, and add that as a tag.
        my $alpha = Foswiki::Func::getRegularExpression('mixedAlphaNum');

        #my $capitalized = qr/[$upper][$alpha]+/;
        use Foswiki::Plugins::TagsPlugin::Tag;
        $text =~
s/[;,\s]([$alpha]+)Category[;,\s]/Foswiki::Plugins::TagsPlugin::Tag::do($item_type, "$web.$topic", $1, $user_id);Foswiki::Plugins::TagsPlugin::Tag::do('tag', $1, $web, $user_id);''/geo;
#        Foswiki::Plugins::TagsPlugin::Tag::do( $item_type, "$web.$topic", $tag, Foswiki::Func::getCanonicalUserID("AdminUser") );
    }

    if ( defined( $Foswiki::cfg{TagsPlugin}{EnableDataForms} )
        && $Foswiki::cfg{TagsPlugin}{EnableDataForms} )
    {

        #add formname as tag - if present
        my $formName = $meta->getFormName();
        if ( $formName ne '' ) {
            Foswiki::Plugins::TagsPlugin::Tag::do( $item_type, "$web.$topic",
                $formName, $user_id );

            #TODO: tag that tag with FormName..
        }
    }
    return;
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
CREATE TABLE IF NOT EXISTS `TagsPlugin_info` (
  `name` varchar(255) NOT NULL,
  `value` varchar(255) NOT NULL,
   PRIMARY KEY  (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=904 DEFAULT CHARSET=latin1;
END
    $arrayRef = $db->dbInsert($statement);


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
  `public` int(10) unsigned NOT NULL,
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

#TODO: save the schema version.
#    $statement = <<'END';
#UPDATE 
#END
#    $arrayRef = $db->dbInsert($statement);


    #add basic tags
    # - each topic is tagged with the web its in (tag type?)
    # - import TagMe tags
    my $count   = 0;
    my $user_id = Foswiki::Plugins::TagsPlugin::Db::createUserID();
    use Foswiki::Plugins::TagsPlugin::Tag;
    my @weblist = Foswiki::Func::getListOfWebs();
    foreach my $web (@weblist) {
        my @topiclist = Foswiki::Func::getTopicList($web);
        foreach my $topic (@topiclist) {
            updateTopicTags( 'topic', $web, $topic, $user_id );
            $count++;
        }
        Foswiki::Plugins::TagsPlugin::Tag::do( 'tag', $web, 'web', $user_id );
    }

    $db->disconnect();    #force a commit

    # write the version of the db schema to a file in the work area
    my $workArea = Foswiki::Func::getWorkArea($pluginName);
    if ( $workArea !~ m/.*\/$/ ) {
        $workArea .= "/";
    }
    Foswiki::Func::saveFile( $workArea . "db_schema_version.txt", "1.1" );

    return 'ok ' . $count;
}

sub convertDatabase {

#TODO: if there are more than two schemata to convert between, this needs to be more complex
    my $db        = new Foswiki::Contrib::DbiContrib;
    my $statement = <<'END';
ALTER TABLE `UserItemTag` ADD COLUMN `public` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `tag_id`;
END
    my $arrayRef = $db->dbInsert($statement);
    
    $statement = <<'END';
CREATE TABLE IF NOT EXISTS `TagsPlugin_info` (
  `name` varchar(255) NOT NULL,
  `value` varchar(255) NOT NULL,
   PRIMARY KEY  (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=904 DEFAULT CHARSET=latin1;
END
    $arrayRef = $db->dbInsert($statement);
    
    $db->disconnect();    #force a commit

    return "ok";
}

sub importTagMe {
    use Foswiki::Plugins::TagsPlugin::ImportTagMe;
    return Foswiki::Plugins::TagsPlugin::ImportTagMe::rest(@_);
}

1;
