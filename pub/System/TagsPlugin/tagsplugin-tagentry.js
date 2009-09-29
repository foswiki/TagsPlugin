        (function($){
          $(function(){

            $("#tagsplugin_taginput_form").bind(
              'submit',
              function(event) {
                event.preventDefault();
                $("#tagsplugin_processing img").show();
                var tag = $("#tagsplugin_taginput_input").val();
                var user = $("div#tagsplugin_taginput form input[name=user]").attr("value");
                tagsplugin_tagentry_tag(tag, foswiki.web+'.'+foswiki.topic, user );
                $("#tagsplugin_taginput_input").trigger("blur").val("").focus();
              }
            );

            // public checkbox
            $("div#tagsplugin_taginput form input[name=user]")
            .attr("checked", "checked")
            .val(foswiki.tagsplugin.public)
            .removeAttr("disabled")
            .bind(
              'click',
              function(event) {
                if ( $(this).is(":checked") ) {
                  $(this).val(foswiki.tagsplugin.public);
                } else {
                  $(this).val("");
                }
              }
            );

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

          }); // ready handler

          function tagsplugin_tagentry_tag(tag, item, user) {
            $.ajax(
              { url: foswiki.scriptUrl+'/rest/TagsPlugin/tag',
                type: "POST",
                data: { tag  : tag,
                        item : item,
                        user : user
                      },
                complete: function(xhr, statusText) {
                            switch (xhr.status) {
                              case 200:
                                break;
                              case 400:
                                tagsplugin_alert("Assuming you are logged-in and assuming you provided a tag name you probably just revealed a software bug. I'm sorry about that. (400)");
                                break;
                              case 401:
                                tagsplugin_alert("According to my data, you are not logged in. Please log-in before you retry.");
                                break;
                              case 403:
                                tagsplugin_alert("I'm sorry, but you are not allowed to do that.");
                                break;
                              case 500:
                                tagsplugin_alert("Something beyond your sphere of influence went wrong. Most probably a problem with the database. May I kindly ask you to inform your administrator? Thank you.");
                                break;
                              default:
                                tagsplugin_alert("Unknown error in tagsplugin_be_tag.");
                                break;
                            }
                            $("#tagsplugin_processing img").hide();
                          }
              }
            );
          }

        })(jQuery);
