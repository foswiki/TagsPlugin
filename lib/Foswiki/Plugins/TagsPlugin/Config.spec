# ---+ Extensions
# ---++ TagsPlugin
# **BOOLEAN**
# setting use to allow you to replace Webs with Tags
$Foswiki::cfg{TagsStore}{FilterByTags} = 0;

# **BOOLEAN**
# automatically create a "web" tag on each topic
$Foswiki::cfg{TagsPlugin}{EnableWebTags} = 1;

# **BOOLEAN**
# automatically create tags for links to topics ending in Category
$Foswiki::cfg{TagsPlugin}{EnableCategories} = 1;

# **BOOLEAN**
# automatically create tags for attached DataForms
$Foswiki::cfg{TagsPlugin}{EnableDataForms} = 1;

# **BOOLEAN**
# enable the built-in TAGCLOUD macro
$Foswiki::cfg{TagsPlugin}{EnableTagCloud} = 1;

# **STRING**
# Name of the TagAdminGroup (which is allowed to delete, rename and merge tags)
$Foswiki::cfg{TagsPlugin}{TagAdminGroup} = "AdminGroup";