(function($){
  $(function(){

        // form submit-bindings
        $("#tagsplugin_taginput_form").bind(
          'submit',
          function(event) {
                event.preventDefault();
                $("#tagsplugin_processing img").show();
                var tag = $("#tagsplugin_taginput_input").val();
                var user = $("div#tagsplugin_taginput form input[name=user]").attr("value");
                var pub = $("div#tagsplugin_taginput form input[name=public]").val();
                jQuery.tagsplugin.tag(tag, { user: user,public: pub, warn_unchanged: true, completed: function(){}  } );
                $("#tagsplugin_taginput_input").trigger("blur").val("").focus();
          }
        );

        // autocomplete for tagentry
        var tagsplugin_taginput_input = $("#tagsplugin_taginput_input");
        var tagsplugin_autocomplete_webdefault = tagsplugin_taginput_input.attr("autocomplete_web");
        tagsplugin_taginput_input.autocomplete(
          foswiki.SCRIPTURL+"/view/"+foswiki.SYSTEMWEB+"/TagsPluginAutoCompleteBackend", {
                extraParams: { skin:"text", cover:"text", web: tagsplugin_autocomplete_webdefault },
                multiple:    false,
                highlight:   false,
                autoFill:    false,
                selectFirst: false,
                formatItem:  function(row, index, max, search) {
                        return row[0];
                },
                formatResult: function(row, index, max) {
                        return row[0];
                }
          }
        );
  
  });	
})(jQuery);
