# This script Copyright (c) 2010 Oliver Krueger, (wiki-one.net)
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

package Foswiki::Plugins::TagsPlugin::Db;

use strict;
use warnings;
use Error qw(:try);

use constant DEBUG => 0; # toggle me

=begin TML

---++ createUserID( $foswiki_cuid )
Resolves a given wikiname to the id in the database. Creates a new entry if necessary.

If the user_id is not given, the currently logged in user is taken.

Parameters:
   * foswiki_cuid : a cuid of a user or a wikiname of group.

Return:
   * (numerical) ID from the database, which identifies the user.

=cut

sub createUserID {
    my $user_id = $_[0];

    my $FoswikiCuid = $user_id || Foswiki::Func::getCanonicalUserID();

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

    $db->commit();

    return $cuid;
}


=begin TML

---++ getUserID( $user )
resolves the cuid for $user from the database

Returns:
   * cuid value
=cut

sub getUserID {
    my $user = $_[0];
    my $user_id = Foswiki::Func::isGroup( $user ) ? $user : Foswiki::Func::getCanonicalUserID( $user );

    my $db = new Foswiki::Contrib::DbiContrib;

    my $cuid;
    my $statement =
      sprintf( 'SELECT %s from %s WHERE %s = ? ', qw( CUID Users FoswikicUID) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::getUserID: $statement - $user_id") if DEBUG;
    my $arrayRef = $db->dbSelect( $statement, $user_id );
    if ( defined( $arrayRef->[0][0] ) ) {
        $cuid = $arrayRef->[0][0];
        Foswiki::Func::writeDebug("TagsPlugin::Db::getUserID: $cuid") if DEBUG;
    }

    return $cuid;
}

=begin TML

---++ getTagID( $tag )
resolves the tag_id for $tag from the database

Returns:
   * tag_id value or "0E0" on (error or nothing found)
=cut

sub getTagID {
    my $tag = $_[0];

    my $db = new Foswiki::Contrib::DbiContrib;
    my $tag_id = "0E0";

    my $statement = sprintf( 'SELECT %s FROM %s WHERE binary %s = ? AND %s = ?', qw( item_id Items item_name item_type) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::getTagID: $statement, $tag, tag") if DEBUG;
    my $arrayRef = $db->dbSelect( $statement, $tag, 'tag' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tag_id = $arrayRef->[0][0];
    }

    return $tag_id;
}

=begin TML

---++ getItemID( $item )
resolves the item_id for $item from the database

Returns:
   * item_id value or "0E0" on error
=cut

sub getItemID {
    my $item = $_[0];

    my $db = new Foswiki::Contrib::DbiContrib;
    my $item_id = "0E0";

    my $statement = sprintf( 'SELECT %s FROM %s WHERE binary %s = ? AND %s = ?', qw( item_id Items item_name item_type) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::getItemID: $statement, $item, topic") if DEBUG;
    my $arrayRef = $db->dbSelect( $statement, $item, 'topic' );
    if ( defined( $arrayRef->[0][0] ) ) {
        $item_id = $arrayRef->[0][0];
    }

    return $item_id;
}

=begin TML

---++ updateTagStat( $tag_id )
rebuild the TagStat table for a certain tag_id

Returns:
   * 0E0 on database errors or
   * tag count otherwise
=cut

sub updateTagStat {
    my $tag_id = $_[0];

    my $db = new Foswiki::Contrib::DbiContrib;

    # count all instances of this tag
    my $tagstat = 0;
    my $statement = sprintf( 'SELECT COUNT(*) AS count FROM %s WHERE %s = ?',
        qw( UserItemTag tag_id ) );
    my $arrayRef = $db->dbSelect( $statement, $tag_id );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tagstat = $arrayRef->[0][0];
    }

    # update the stats (assume, there is already an entry)
    $statement = sprintf( 'UPDATE %s SET %s=? WHERE %s = ?', qw( TagStat num_items tag_id) );
    my $modified = $db->dbInsert( $statement, $tagstat, $tag_id );
    Foswiki::Func::writeDebug("TagsPlugin::Db::updateTagStat: $statement; ($tagstat, $tag_id) -> $modified") if DEBUG;
    if ( $modified eq "0E0" ) {
      return $modified;
    };

    # create new stat line (in case there was no entry)
    unless ( $modified ) {
        $statement = sprintf( 'INSERT INTO %s (%s, %s) VALUES (?, ?)',
            qw( TagStat tag_id num_items ) );
        $modified = $db->dbInsert( $statement, $tag_id, $tagstat );
        Foswiki::Func::writeDebug("TagsPlugin::Db::updateTagStat: $statement; ($tag_id, $tagstat) -> $modified") if DEBUG;
        if ( $modified eq "0E0" ) {
          return $modified;
        };
    }

    $db->commit();

    return $tagstat;
}

=begin TML

---++ updateUserTagStat( $tag_id, $user_id )
rebuild the UserTagStat table for a given user_id and tag_id

Returns:
   * 0E0 on database errors or
   * tag count otherwise
=cut

sub updateUserTagStat {
    my $tag_id  = $_[0];
    my $user_id = $_[1];

    my $db = new Foswiki::Contrib::DbiContrib;

    # count all instances of this tag
    my $tagstat = 0;
    my $statement = sprintf( 'SELECT COUNT(*) AS count FROM %s WHERE %s = ? AND %s = ?',
        qw( UserItemTag user_id tag_id ) );
    my $arrayRef = $db->dbSelect( $statement, $user_id, $tag_id );
    if ( defined( $arrayRef->[0][0] ) ) {
        $tagstat = $arrayRef->[0][0];
    }

    # update the stats (assume, there is already an entry)
    $statement = sprintf( 'UPDATE %s SET %s=? WHERE %s = ? AND %s = ?', qw( TagStat num_items user_id tag_id) );
    my $modified = $db->dbInsert( $statement, $tagstat, $user_id, $tag_id );
    Foswiki::Func::writeDebug("TagsPlugin::Db::updateUserTagStat: $statement; ($tagstat, $user_id, $tag_id) -> $modified") if DEBUG;
    if ( $modified eq "0E0" ) {
      return $modified;
    };

    # create new stat line (in case there was no entry)
    unless ( $modified ) {
        $statement = sprintf( 'INSERT INTO %s (%s, %s, %s) VALUES (?, ?, ?)',
            qw( TagStat user_id tag_id num_items ) );
        $modified = $db->dbInsert( $statement, $user_id, $tag_id, $tagstat );
        Foswiki::Func::writeDebug("TagsPlugin::Db::updateUserTagStat: $statement; ($user_id, $tag_id, $tagstat) -> $modified") if DEBUG;
        if ( $modified eq "0E0" ) {
          return $modified;
        };
    }

    $db->commit();

    return $tagstat;
}

=begin TML

---++ updateUserTagStatAll( $tag_id )
iterates over all affected users and rebuild the UserTagStat table for those users and tag_id

Returns:
   * 0E0 on one of more database errors or
   * 1 otherwise
=cut

sub updateUserTagStatAll {
    my $tag_id = $_[0];
    my $retval = "1";

    my $db = new Foswiki::Contrib::DbiContrib;

    my $statement = sprintf( 'SELECT %s FROM %s WHERE %s = ?', qw( user_id UserItemTag tag_id ) );
    my $arrayRef = $db->dbSelect( $statement, $tag_id );
    foreach my $row ( @{$arrayRef} ) {
        my $user_id = $row->[0];
        if ( updateUserTagStat( $tag_id, $user_id ) eq "0E0" ) {
          $retval = "0E0";
        }
    }

    return $retval;
    
}

=begin TML

---++ deleteTag( $tag_id )
Purges an entire tag from the database including stats.

Starts purging in both Stat tables, continues in UserItemTag and ends in Items.

Returns:
   * 0E0 on one of more database errors or
   * 1 otherwise
=cut

sub deleteTag {
    my $tag_id = $_[0];
    my $retval = "1";

    my $db = new Foswiki::Contrib::DbiContrib;

    # update UserTagStat
    my $statement = sprintf( 'DELETE from %s WHERE %s = ?', qw( UserTagStat tag_id ) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::deleteTag: $statement; ($tag_id)") if DEBUG;
    my $affected_rows = $db->dbDelete( $statement, $tag_id );
    if ( $affected_rows eq "0E0" ) { $retval = "0E0"; };

    # update TagStat
    $statement = sprintf( 'DELETE from %s WHERE %s = ?', qw( TagStat tag_id ) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::deleteTag: $statement; ($tag_id)") if DEBUG;
    $affected_rows = $db->dbDelete( $statement, $tag_id );
    if ( $affected_rows eq "0E0" ) { $retval = "0E0"; };

    # update UserItemTag
    $statement = sprintf( 'DELETE from %s WHERE %s = ?', qw( UserItemTag tag_id ) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::deleteTag: $statement; ($tag_id)") if DEBUG;
    $affected_rows = $db->dbDelete( $statement, $tag_id );
    if ( $affected_rows eq "0E0" ) { $retval = "0E0"; };

    # update Items
    $statement = sprintf( 'DELETE from %s WHERE %s = ?', qw( Items item_id ) );
    Foswiki::Func::writeDebug("TagsPlugin::Db::deleteTag: $statement; ($tag_id)") if DEBUG;
    $affected_rows = $db->dbDelete( $statement, $tag_id );
    if ( $affected_rows eq "0E0" ) { $retval = "0E0"; };

    # flushing data to dbms
    $db->commit();

    return $retval;
}


=begin TML

---++ handleDuplicatePublics()
Finds and destroys multiple public (item,tag) tupels.

Returns:
   * 0E0 on one of more database errors or
   * 1 otherwise
=cut

sub handleDuplicatePublics {

    my $db = new Foswiki::Contrib::DbiContrib;

    my $statement = sprintf( 'SELECT %s, %s, %s, COUNT(%s) AS c FROM %s WHERE %s = ? GROUP BY %s, %s HAVING c>1', qw( item_id tag_id user_id item_id UserItemTag public tag_id item_id ) );
    Foswiki::Func::writeDebug("Outer Select: $statement, 1") if DEBUG;
    my $arrayRef = $db->dbSelect( $statement, 1 );
    foreach my $row ( @{$arrayRef} ) {
        my $item_id = $row->[0];
        my $tag_id  = $row->[1];
        my $counter = 0;
        my $subStatement = sprintf( 'SELECT %s, %s, %s, %s FROM %s WHERE %s = ? AND %s = ? AND %s = ?', qw( item_id tag_id user_id public UserItemTag public tag_id item_id ) );
        Foswiki::Func::writeDebug("Inner Select: $subStatement, 1, $tag_id, $item_id") if DEBUG;
        my $subArrayRef = $db->dbSelect( $subStatement, 1, $tag_id, $item_id );
        foreach my $subRow ( @{$subArrayRef} ) {
            next if ( $counter == 0 );
            $counter++;
            my $user_id = $subRow->[2];
            my $deleteStatement = sprintf( 'DELETE FROM %s WHERE %s = ? AND %s = ? AND %s = ? AND %s = ?', qw( UserItemTag public item_id tag_id user_id ) );
            my $affected_rows = $db->dbDelete( $deleteStatement, 1, $item_id, $tag_id, $user_id );
            Foswiki::Func::writeWarning("TagsPlugin: Unable to delete duplicate public tag/item-tupels: $deleteStatement, 1, $item_id, $tag_id, $user_id") if ( $affected_rows eq "0E0" );
        }
    }
    $db->commit();
}



1;
