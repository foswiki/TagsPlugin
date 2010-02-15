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
        $("#tagsplugin_taginput_input").autocomplete(
          foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/TagsPluginAutoCompleteBackend", {
                extraParams: { skin:"text", cover:"text" },
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
