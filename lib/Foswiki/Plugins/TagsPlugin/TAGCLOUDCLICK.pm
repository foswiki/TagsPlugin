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

package Foswiki::Plugins::TagsPlugin::TAGCLOUDCLICK;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ do( $session, $params, $topic, $web )
Taghandler for TAGCLOUDCLICK.

Returns an INCLUDE statement based on the input parameters plus add meta data to html header and include a js file.

Return:
 Clickable Tag Cloud.
=cut

sub do {
    my ( $session, $params, $topic, $web ) = @_;

    my $theSourceUser  = $params->{sourceuser}  || "all";
    my $theTargetUser  = $params->{targetuser}  || Foswiki::Func::getPreferencesValue("TAGSPLUGIN_TAGUSER") || Foswiki::Func::getWikiName();
    my $theSourceWeb   = $params->{sourceweb}   || $web;
    my $theTargetWeb   = $params->{targetweb}   || $web;
    my $theTargetTopic = $params->{targettopic} || $topic;
    my $theCloudTopic  = $params->{cloudtopic}  || "%SYSTEMWEB%.TagsPluginTagCloud";

    my $header = "<meta name='foswiki.tagsplugin.cloudclick.targetuser' content='$theTargetUser' />\n"; 
    $header .= "<meta name='foswiki.tagsplugin.cloudclick.targetweb' content='$theTargetWeb' />\n"; 
    $header .= "<meta name='foswiki.tagsplugin.cloudclick.targettopic' content='$theTargetTopic' />\n"; 
    $header .= "<meta name='foswiki.tagsplugin.cloudclick.sourceuser' content='$theSourceUser' />\n"; 
    $header .= "<meta name='foswiki.tagsplugin.cloudclick.sourceweb' content='$theSourceWeb' />\n"; 
    $header .= "<meta name='foswiki.tagsplugin.cloudclick.cloudtopic' content='$theCloudTopic' />\n"; 
    $header .= "<script type='text/javascript' src='%PUBURL%/System/TagsPlugin/tagsplugin-cloudclick.js'></script>\n";
    Foswiki::Func::addToHEAD('TAGSPLUGIN::CLOUDCLICK', "\n".$header );
    
    my $output = "<div id='tagsplugin_cloudclick'>%INCLUDE{\"$theCloudTopic\" TAGUSER=\"$theSourceUser\" TAGWEB=\"$theSourceWeb\"}%</div>\n";
    $output .= "<div id='tagsplugin_cloudclick_processing'>%ICON{processing-bg}%</div>\n";
    $output .= "<div id='tagsplugin_cloudclick_dialog' />\n";
    return $output;
}

1;
