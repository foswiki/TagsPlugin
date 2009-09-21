        (function($){ 
          $(function(){
            tagsplugin_cloudclick_refresh()
          }); // ready handler

          function tagsplugin_cloudclick_mark() {
            
            $("div#tagsplugin_cloudclick .tagsplugin_tagcloud_tag:not(.tagsplugin_tagcloud_tag_bound)")
            .bind(
              'click',
              function(event) { 
                event.preventDefault();
                tagsplugin_cloudclick_toggletag(event); 
              }
            )
            .addClass("tagsplugin_tagcloud_tag_bound");
            $.getJSON(
              foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/TagsPluginTagListJSON",
              { 
                skin:     "text", 
                cover:    "text", 
                tagweb:   foswiki.tagsplugin.cloudclick.targetweb, 
                tagtopic: foswiki.tagsplugin.cloudclick.targettopic, 
                taguser:  foswiki.tagsplugin.cloudclick.targetuser 
              },
              function(data) {
                for(var i = 0; i < data.length; i++)
                  $("div#tagsplugin_cloudclick .tagsplugin_tagcloud_tag[tag='"+data[i]+"']").addClass("tagsplugin_tagged");
              }
            )
          }

          function tagsplugin_cloudclick_toggletag(event) {
            if ( $(event.target).hasClass("tagsplugin_tagged") ) {
              $("#tagsplugin_cloudclick_processing img").show();
              var tag  = $(event.target).attr("tag");
              var item = foswiki.tagsplugin.cloudclick.targetweb+"."+foswiki.tagsplugin.cloudclick.targettopic;
              var user = foswiki.tagsplugin.cloudclick.targetuser;
              tagsplugin_be_untag( tag, item, user );
              $(event.target).removeClass("tagsplugin_tagged");
            } else {
              $("#tagsplugin_cloudclick_processing img").show();
              var tag  = $(event.target).attr("tag");
              var item = foswiki.tagsplugin.cloudclick.targetweb+"."+foswiki.tagsplugin.cloudclick.targettopic;
              var user = foswiki.tagsplugin.cloudclick.targetuser;
              tagsplugin_be_tag( tag, item, user );
              $(event.target).addClass("tagsplugin_tagged");
            }
          }

          function tagsplugin_cloudclick_refresh() {
            $("#tagsplugin_cloudclick_processing img").show();
            $.get(
              foswiki.scriptUrl+"/view/"+foswiki.tagsplugin.cloudclick.cloudtopic,
              { skin    : "text",
                cover   : "text",
                tagweb  : foswiki.tagsplugin.cloudclick.sourceweb,
                taguser : foswiki.tagsplugin.cloudclick.sourceuser 
              },
              function(data) { 
                $("div#tagsplugin_cloudclick").html(data);
                tagsplugin_cloudclick_mark(); 
                $("#tagsplugin_cloudclick_processing img").hide();
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
                                tagsplugin_cloudclick_refresh();
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
                            $("#tagsplugin_cloudclick_processing img").hide();
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
                                tagsplugin_cloudclick_refresh();
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
                            $("#tagsplugin_cloudclick_processing img").hide();
                          }
              }
            );
          }

          function tagsplugin_alert(text) {
            $("#tagsplugin_cloudclick_dialog")
            .html(text)
            .dialog()
            .dialog('option', 'modal', true)
            .dialog('option', 'width', 460)
            .dialog('option', 'title', 'May I kindly ask for your attention?')
            .dialog('option', 'buttons', { "Ok": function() { $(this).dialog("close"); } })
            .dialog("open");
          }

        })(jQuery);
