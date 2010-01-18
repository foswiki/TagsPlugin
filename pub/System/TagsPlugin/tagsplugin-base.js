        (function($){
          $(function(){

            tagsplugin_fe_redirect_details();

            // Tags-Button
            $("#tagsplugin_tagcloud_toggle").bind(
              'click',
              function() {
                if ( $("div#tagsplugin_tagcloud_tags").is(':hidden') ) {
                  tagsplugin_fe_refreshTagCloud();
                  $("div#tagsplugin_tagcloud_tags").show();
                  $("div#tagsplugin_filters").show();
                } else {
                  $("div#tagsplugin_filters").hide();
                  $("div#tagsplugin_tagcloud_tags").hide();
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
                tagsplugin_fe_refreshTagCloud();
              }
            );

            // userselector bindings
            $("div#tagsplugin .tagsplugin_user").bind(
              'click',
              function(event) {
                event.preventDefault();
                $(".tagsplugin_user_active").removeClass("tagsplugin_user_active");
                $(event.target).closest("a.tagsplugin_user[user]").addClass("tagsplugin_user_active");
                tagsplugin_fe_refreshTagCloud();
              }
            );

            // form submit-bindings
            $("#tagsplugin_taginput_form").bind(
              'submit',
              function(event) {
                event.preventDefault();
                $("#tagsplugin_processing img").show();
                var tag = $("#tagsplugin_taginput_input").val();
                var user = $("div#tagsplugin_taginput form input[name=user]").attr("value");
                // var pub = $("div#tagsplugin_taginput form input[name=public]").is(":checked") ? "1" : "0";
                var pub = $("div#tagsplugin_taginput form input[name=public]").val();
                tagsplugin_be_tag(tag, foswiki.web+'.'+foswiki.topic, user, pub );
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

          }); // ready handler

          function tagsplugin_fe_redirect_details() {
            $("div#tagsplugin .tagsplugin_tag")
            .add("div#tagsplugin .tagsplugin_tagcloud_tag")
            .bind(
              'click',
              function(event) {
                event.preventDefault();
                var web   = foswiki.web;
                var topic = foswiki.topic;
                var tag   = $(event.target).closest("a[tag]").attr("tag");
                var user  = $(event.target).closest("a[tag]").attr("user");
                $("#tagsplugin_processing img").show();
                if ( $("#tagsplugin_dialog_details").size() == 0 ) {
                $("<div id='tagsplugin_dialog_details' />")
                .dialog( { autoOpen: false } )
                .load(
                  foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/TagsPluginTagDetailsSimple?skin=text&cover=text&tag="+escape(tag)+"&tagweb="+escape(web)+"&tagtopic="+escape(topic)+"&taguser="+escape(user),
                  null,
                  function() {
                    $("#tagsplugin_dialog_details")
                    .dialog('option', 'modal', true)
                    .dialog('option', 'width', 460)
                    .dialog('option', 'title', foswiki.tagsplugin.translation.TagDetailsOn+' '+tag)
                    .dialog("open")
                    .bind( 
                      'dialogclose', 
                      function(event,ui) {
                        $("#tagsplugin_dialog_details").remove();
                      } 
                    );
                    $(".tagsplugin_untag_link").bind(
                      'click',
                      function(event) {
                        event.preventDefault();
                        var tag  = $(event.target).attr("tag");
                        var item = $(event.target).attr("item");
                        var user = $(event.target).attr("user");
                        $("#tagsplugin_dialog_details").dialog("close");
                        $("#tagsplugin_processing img").show();
                        tagsplugin_be_untag(tag, item, user);
                      }
                    );
                    $("#tagsplugin_processing img").hide();
                  }
                ); }
              }
            );
          }

          function tagsplugin_fe_refreshTagList() {
            $("#tagsplugin_processing img").show();
            $.get(
              foswiki.scriptUrl+"/view/"+foswiki.systemWebName+'/TagsPluginTagList',
              { skin: 'text', cover: 'text', tagweb: foswiki.web, tagtopic: foswiki.topic },
              function(data) {
                $("#tagsplugin_taglist_tags").html(data);
                tagsplugin_fe_redirect_details();
                $("#tagsplugin_processing img").hide();
              }
            );
          }

          function tagsplugin_fe_refreshTagCloud() {
            $("#tagsplugin_processing img").show();
            $.get(
              foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/TagsPluginTagCloud",
              { skin     : "text",
                cover    : "text",
                tagweb   : $(".tagsplugin_web_active").attr("web"),
                taguser  : $(".tagsplugin_user_active").attr("user")
              },
              function(data) {
                $("#tagsplugin_tagcloud_tags").html(data);
                tagsplugin_fe_redirect_details();
                $("#tagsplugin_processing img").hide();
              }
            );
          }

          function tagsplugin_be_tag(tag, item, user, pub) {
            $.ajax(
              { url: foswiki.scriptUrl+'/rest/TagsPlugin/tag',
                type: "POST",
                data: { tag    : tag,
                        item   : item,
                        user   : user,
                        public : pub
                      },
                complete: function(xhr, statusText) {
                            switch (xhr.status) {
                              case 200:
                                tagsplugin_fe_refreshTagList();
                                break;
                              case 400:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Tag400 );
                                break;
                              case 401:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Tag401 );
                                break;
                              case 403:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Tag403 );
                                break;
                              case 500:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Tag500 );
                                break;
                              default:
                                tagsplugin_alert( foswiki.tagsplugin.translation.TagUnknown );
                                break;
                            }
                            $("#tagsplugin_processing img").hide();
                          }
              }
            );
          }

          function tagsplugin_be_untag(tag, item, user) {
            $.ajax(
              { url: foswiki.scriptUrl+'/rest/TagsPlugin/untag',
                type: "POST",
                data: { tag  : tag,
                        item : item,
                        user : user
                      },
                complete: function(xhr, statusText) {
                            switch (xhr.status) {
                              case 200:
                                tagsplugin_fe_refreshTagList();
                                break;
                              case 400:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Untag400 );
                                break;
                              case 401:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Untag401 );
                                break;
                              case 403:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Untag403 );
                                break;
                              case 404:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Untag404 );
                                break;
                              case 500:
                                tagsplugin_alert( foswiki.tagsplugin.translation.Untag500 );
                                break;
                              default:
                                tagsplugin_alert( foswiki.tagsplugin.translation.UntagUnknown );
                                break;
                            }
                            $("#tagsplugin_processing img").hide();
                          }
              }
            );
          }

          function tagsplugin_alert(text) {
            $("<div id='tagsplugin_dialog_error' />")
            .dialog( { autoOpen: false } )
            .html(text)
            .dialog('option', 'modal', true)
            .dialog('option', 'width', 460)
            .dialog('option', 'title', foswiki.tagsplugin.translation.Attention )
            .dialog('option', 'buttons', { "Ok": function() { $(this).dialog("close"); } })
            .dialog("open")
            .bind( 
              'dialogclose', 
              function(event,ui) {
                $("#tagsplugin_dialog_error").remove();
              } 
            );
          }

        })(jQuery);
