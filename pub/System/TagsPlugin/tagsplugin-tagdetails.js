(function($){
  $(function(){

    // close dialog if there is nothing so show
    if ( $("input.tagsplugin_public_checkbox").size() == 0 ) {
      $("#tagsplugin_dialog_details").dialog("close");
    }

    // if there is one public tag, disable all private checkboxes
    if ( $("input:checked.tagsplugin_public_checkbox").size() > 0 ) {
      $("input[type=checkbox]:not(:checked).tagsplugin_public_checkbox")
      .attr("disabled", true);
    };

    $("input[type=checkbox].tagsplugin_public_checkbox")
    .bind(
      "click",
      function(event) {

        $("#tagsplugin_tagdetails_processing").show();
        var item = $(event.target).attr("item");
        var tag  = $(event.target).attr("tag");
        var user = $(event.target).attr("user");

        foswiki.tag = tag; // SMELL

        // toggle between one public checkbox checked and all others disabled
        // and none checked or disabled
        //
        if ( $(event.target).is(":checked") ) {
          $("input[type=checkbox].tagsplugin_public_checkbox")
          .not(event.target)
          .attr("disabled", true);
          jQuery.tagsplugin.public(tag, 1, { user: user,
                                             item: item,
                                             completed: function() { $("#tagsplugin_tagdetails_processing").hide(); }
                                           }
          );
        } else {
          $("input[type=checkbox].tagsplugin_public_checkbox")
          .attr("disabled", false);
          jQuery.tagsplugin.public(tag, 0, { user: user,
                                             item: item,
                                             completed: function() { $("#tagsplugin_tagdetails_processing").hide(); }
                                           }
          );
        }
      }
    );

    $(".tagsplugin_untag_link")
    .bind(
      "click",
      function(event) {
        event.preventDefault();
        var item   = $(event.target).closest("a.tagsplugin_untag_link").attr("item");
        var tag    = $(event.target).closest("a.tagsplugin_untag_link").attr("tag");
        var user   = $(event.target).closest("a.tagsplugin_untag_link").attr("user");
        var public = $(event.target).closest("a.tagsplugin_untag_link").attr("public");

        jQuery.tagsplugin.untag(tag, public, { user      : user, 
                                               item      : item, 
                                               completed : function() { 
                                                 $("#tagsplugin_dialog_details").dialog("close");
                                               } 
                                             } 
        );
      }
    );

    $("#foswikiTagsPluginRename_submit")
    .bind(
      "click",
      function(event) {
        event.preventDefault();

        $("#tagsplugin_tagdetails_processing").show();

        var oldtag     = $("#foswikiTagsPluginRename>input[name=oldtag]").val();
        var newtag     = $("#foswikiTagsPluginRename>input[name=newtag]").val();
        var redirectto = $("#foswikiTagsPluginRename>input[name=redirectto]").val();

        jQuery.tagsplugin.rename(oldtag, newtag, { redirectto : redirectto, 
                                                   completed : function() { 
                                                     $("#tagsplugin_dialog_details").dialog("close");
                                                   } 
                                                 } 
        );
      }
    );

    $("#foswikiTagsPluginMerge_submit")
    .bind(
      "click",
      function(event) {
        event.preventDefault();

        $("#tagsplugin_tagdetails_processing").show();

        var tag2     = $("#foswikiTagsPluginMerge>input[name=tag2]").val();
        var tag1     = $("#foswikiTagsPluginMerge>select[name=tag1]").val();
        var redirectto = $("#foswikiTagsPluginMerge>input[name=redirectto]").val();

        jQuery.tagsplugin.merge(tag1, tag2, { redirectto : redirectto, 
                                              completed : function() { 
                                                $("#tagsplugin_dialog_details").dialog("close");
                                              } 
                                            } 
        );
      }
    );

  });
})(jQuery);
