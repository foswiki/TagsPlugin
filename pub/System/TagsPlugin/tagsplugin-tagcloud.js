(function($){
  $(function(){

        // Tags-Button
        $("#tagsplugin_tagcloud_toggle").bind(
          'click',
          function() {
                if ( $("div#tagsplugin_tagcloud").is(':hidden') ) {
                  refreshTagCloud();
                  $("div#tagsplugin_tagcloud").show();
                } else {
                  $("div#tagsplugin_tagcloud").hide();
                }
          }
        );

        // webselector bindings
        $("div#tagsplugin .tagsplugin_web").bind(
          'click',
          function(event) {
                event.preventDefault();
                $(".tagsplugin_web_active").removeClass("tagsplugin_web_active");
                $(event.target).closest("a.tagsplugin_web[web]").addClass("tagsplugin_web_active");
                refreshTagCloud();
          }
        );

        // userselector bindings
        $("div#tagsplugin .tagsplugin_user").bind(
          'click',
          function(event) {
                event.preventDefault();
                $(".tagsplugin_user_active").removeClass("tagsplugin_user_active");
                $(event.target).closest("a.tagsplugin_user[user]").addClass("tagsplugin_user_active");
                refreshTagCloud();
          }
        );

        // SMELL: does not work as expected
        $("#tagsplugin_tagcloud_tags").live("tagsplugin_update", function() { refreshTagCloud() } );
  
  });	

  function refreshTagCloud() {
        $("#tagsplugin_processing img").show();
        $.get(
          foswiki.SCRIPTURL+"/view/"+foswiki.SYSTEMWEB+"/TagsPluginTagCloud",
          { skin     : "text",
                cover    : "text",
                tagweb   : $(".tagsplugin_web_active").attr("web"),
                taguser  : $(".tagsplugin_user_active").attr("user")
          },
          function(data) {
                $("#tagsplugin_tagcloud_tags").html(data);
                jQuery.tagsplugin.redirect_tagdetails();
                $("#tagsplugin_processing img").hide();
          }
        );
  }

})(jQuery);
