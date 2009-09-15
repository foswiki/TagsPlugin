        (function($){
          $(function(){

            $("#tagsplugin_entryform").bind(
              'submit',
              function(event) {
                event.preventDefault();
                $("#tagsplugin_processing img").show();
                var tag = $("#tagsplugin_taginput_input").val();
                tagsplugin_be_tag(tag, foswiki.web+'.'+foswiki.topic, foswiki.wikiName );
                $("#tagsplugin_taginput_input").trigger("blur").val("").focus();
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
            $(".tagsplugin_web").bind(
              'click',
              function(event) {
                event.preventDefault();
                $(".tagsplugin_web_active").removeClass("tagsplugin_web_active");
                $(event.target).addClass("tagsplugin_web_active");
                tagsplugin_fe_refreshTagCloud();
              }
            );

            // userselector bindings
            $(".tagsplugin_user").bind(
              'click',
              function(event) {
                event.preventDefault();
                $(".tagsplugin_user_active").removeClass("tagsplugin_user_active");
                $(event.target).addClass("tagsplugin_user_active");
                tagsplugin_fe_refreshTagCloud();
              }
            );

          }); // ready handler

          function tagsplugin_fe_redirect_details() {
            $(".tagsplugin_tag_link")
            .add(".tagsplugin_tagcloud_tag")
            .bind(
              'click',
              function(event) {
                event.preventDefault();
                var tag   = $(event.target).attr("tag");
                var web   = $(event.target).attr("web");
                var topic = $(event.target).attr("topic");
                var user  = $(event.target).attr("user");
                $("#tagsplugin_processing img").show();
                $("#tagsplugin_dialog_details")
                .load(
                  foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/TagsPluginTagDetailsSimple?skin=text&cover=text&tag="+escape(tag)+"&tagweb="+escape(web)+"&tagtopic="+escape(topic)+"&taguser="+escape(user),
                  null,
                  function() {
                    $("#tagsplugin_dialog_details")
                    .dialog()
                    .dialog('option', 'modal', true)
                    .dialog('option', 'width', 460)
                    .dialog('option', 'title', 'Tag Details on '+tag)
                    .dialog("open");
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
                );
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

          function tagsplugin_be_tag(tag, item, user) {
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
                                tagsplugin_fe_refreshTagList();
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
                                tagsplugin_alert("Assuming you are logged in you probably just revealed a software bug. I'm sorry about that. (400)");
                                break;
                              case 401:
                                tagsplugin_alert("According to my data, you are not logged in. Please log-in before you retry.");
                                break;
                              case 403:
                                tagsplugin_alert("I'm sorry, but you are not allowed to do that.");
                                break;
                              case 404:
                                tagsplugin_alert("I'm sorry, but either the tag or the topic does not exist.");
                                break;
                              case 500:
                                tagsplugin_alert("Something beyond your sphere of influence went wrong. Most probably a problem with the database. May I kindly ask you to inform your administrator? Thank you.");
                                break;
                              default:
                                tagsplugin_alert("Unknown error in tagsplugin_be_untag.");
                                break;
                            }
                            $("#tagsplugin_processing img").hide();
                          }
              }
            );
          }

          function tagsplugin_alert(text) {
            $("#tagsplugin_dialog_details")
            .html(text)
            .dialog()
            .dialog('option', 'modal', true)
            .dialog('option', 'width', 460)
            .dialog('option', 'title', 'May I kindly ask for your attention?')
            .dialog('option', 'buttons', { "Ok": function() { $(this).dialog("close"); } })
            .dialog("open");
          }

        })(jQuery);

