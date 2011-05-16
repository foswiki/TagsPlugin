(function($){
  $(function(){
	jQuery.tagsplugin = new Object();

        jQuery.tagsplugin.tag = function(tag,options) {
          var settings = $.extend({
            tag:            tag,
            user:           foswiki.wikiName,
            item:           foswiki.web+"."+foswiki.topic,
            public:         1,
            warn_unchanged: false,
            completed: function(){}
          },options||{});

          alert("item: "+settings.item);

          $.ajax(
            { url: foswiki.SCRIPTURL+'/rest/TagsPlugin/tag',
              type: "POST",
              data: { tag    : settings.tag,
                      item   : settings.item,
                      user   : settings.user,
                      public : settings.public
                    },
              complete: function(xhr, statusText) {
                settings.completed();
                switch (xhr.status) {
                  case 200:
                    if ( ($.trim(xhr.responseText) <= 0) && settings.warn_unchanged) {
                      jQuery.tagsplugin.error( foswiki.tagsplugin.translation.NothingChanged );
                    }
                    $(".tagsplugin_update_observer").trigger("tagsplugin_update");
                    break;
                  case 400:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag400 );
                    break;
                  case 401:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag401 );
                    break;
                  case 403:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag403 );
                    break;
                  case 500:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag500 );
                    break;
                  default:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.TagUnknown );
                    break;
                }
              }
            }
          );
        };

        jQuery.tagsplugin.untag = function(tag,public,options) {
          var settings = $.extend({
            tag:            tag,
            user:           foswiki.wikiName,
            item:           foswiki.web+"."+foswiki.TOPIC,
            warn_unchanged: false,
            completed:      function(){}
          },options||{});

          $.ajax(
            { url: foswiki.SCRIPTURL+'/rest/TagsPlugin/untag',
              type: "POST",
              data: { tag    : settings.tag,
                      item   : settings.item,
                      user   : settings.user,
                      public : public
                    },
              complete: function(xhr, statusText) {
                settings.completed();
                switch (xhr.status) {
                  case 200:
                    if ( ($.trim(xhr.responseText) <= 0) && settings.warn_unchanged) {
                      jQuery.tagsplugin.error( foswiki.tagsplugin.translation.NothingChanged );
                    }
                    $(".tagsplugin_update_observer").trigger("tagsplugin_update");
                    break;
                  case 400:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag400 );
                    break;
                  case 401:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag401 );
                    break;
                  case 403:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag403 );
                    break;
                  case 404:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag404 );
                    break;
                  case 500:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.Tag500 );
                    break;
                  default:
                    jQuery.tagsplugin.error( foswiki.tagsplugin.translation.TagUnknown );
                    break;
                }
              }
            }
          );
        };

        jQuery.tagsplugin.public = function(tag,public,options) {
          var settings = $.extend({
            tag:       tag,
            user:      foswiki.wikiName,
            item:      foswiki.web+"."+foswiki.TOPIC,
            public:    public,
            completed: function(){}
          },options||{});

          $.ajax(
            { url: foswiki.SCRIPTURL+'/rest/TagsPlugin/public',
              type: "POST",
              data: { tag    : settings.tag,
                      item   : settings.item,
                      user   : settings.user,
                      public : settings.public
                    },
              complete: function(xhr, statusText) {
                settings.completed();
                $("#tagsplugin_dialog_details").dialog("close");
                $(".tagsplugin_update_observer").trigger("tagsplugin_update");
              }
            }
          );
        };

        jQuery.tagsplugin.rename = function(oldtag,newtag,options) {
          var settings = $.extend({
            oldtag:     oldtag,
            newtag:     newtag,
            redirectto: "",
            completed: function(){}
          },options||{});

          $.ajax(
            { url: foswiki.SCRIPTURL+'/rest/TagsPlugin/rename',
              type: "POST",
              data: { oldtag     : settings.oldtag,
                      newtag     : settings.newtag,
                      redirectto : settings.redirectto
                    },
              complete: function(xhr, statusText) {
                settings.completed();
                $("#tagsplugin_dialog_details").dialog("close");
                $(".tagsplugin_update_observer").trigger("tagsplugin_update");
              }
            }
          );
        };

        jQuery.tagsplugin.merge = function(tag1,tag2,options) {
          var settings = $.extend({
            tag1:     tag1,
            tag2:     tag2,
            redirectto: "",
            completed: function(){}
          },options||{});

          $.ajax(
            { url: foswiki.SCRIPTURL+'/rest/TagsPlugin/merge',
              type: "POST",
              data: { tag1       : settings.tag1,
                      tag2       : settings.tag2,
                      redirectto : settings.redirectto
                    },
              complete: function(xhr, statusText) {
                settings.completed();
                $("#tagsplugin_dialog_details").dialog("close");
                $(".tagsplugin_update_observer").trigger("tagsplugin_update");
              }
            }
          );
        };

        jQuery.tagsplugin.changeOwner = function(tag,public,options) {
          var settings = $.extend({
            tag:       tag,
            user:      foswiki.wikiName,
            newuser:   foswiki.wikiName,
            item:      foswiki.web+"."+foswiki.TOPIC,
            public:    public,
            completed: function(){}
          },options||{});

          foswiki.tag = tag; // SMELL

          $.ajax(
            { url: foswiki.SCRIPTURL+'/rest/TagsPlugin/changeOwner',
              type: "POST",
              data: { tag     : settings.tag,
                      item    : settings.item,
                      user    : settings.user,
                      newuser : settings.newuser,
                      public  : settings.public
                    },
              complete: function(xhr, statusText) {
                settings.completed();
                $("#tagsplugin_dialog_details").dialog("close");
                $(".tagsplugin_update_observer").trigger("tagsplugin_update");
              }
            }
          );
        };

        jQuery.tagsplugin.error = function(text) {
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

        jQuery.tagsplugin.redirect_tagdetails = function() {
          $(".tagsplugin_tag")
          .add(".tagsplugin_tagcloud_tag")
          .bind(
            'click',
            function(event) {

              event.preventDefault();

              var web         = $(event.target).closest("[web]").attr("web"); 
              var topic       = $(event.target).closest("[topic]").attr("topic");
              var tag         = $(event.target).closest("[tag]").attr("tag");
              var dialog_type = $(event.target).closest("[dialog]").attr("dialog");

              $("#tagsplugin_processing img").show();
              if ( $("#tagsplugin_dialog_details").size() == 0 ) {
                $("<div id='tagsplugin_dialog_details' class='tagsplugin_update_observer' />")
                .dialog( { autoOpen: false } )
                .dialog('option', 'modal', true)
                .dialog('option', 'width', 600)
                .dialog('option', 'title', foswiki.tagsplugin.translation.TagDetailsOn+' '+tag)
                .bind(
                  'dialogclose',
                  function(event,ui) {
                    $("#tagsplugin_dialog_details").remove();
                  }
                );
                refreshTagDetailsDialog( tag, web, topic, dialog_type );
              }
            }
          );
        }

        $("#tagsplugin_taglist_tags.tagsplugin_update_observer").live("tagsplugin_update", function() { refreshTagList() } );
        $("#tagsplugin_dialog_details.tagsplugin_update_observer").live("tagsplugin_update", function() { refreshTagDetailsDialog( foswiki.tag, foswiki.web, foswiki.TOPIC, "Simple" ) } );

	jQuery.tagsplugin.redirect_tagdetails();

  }); // ready handler

  function refreshTagList() {
	$("#tagsplugin_processing img").show();
	$.get(
	  foswiki.SCRIPTURL+"/view/"+foswiki.SYSTEMWEB+'/TagsPluginTagList',
	  { skin: 'text', cover: 'text', tagweb: foswiki.web, tagtopic: foswiki.TOPIC },
	  function(data) {
		$("#tagsplugin_taglist_tags").html(data);
		jQuery.tagsplugin.redirect_tagdetails();
		$("#tagsplugin_processing img").hide();
	  }
	);
  }

  function refreshTagDetailsDialog( tag, web, topic, dialog_type ) {
    if ( dialog_type == undefined ) {
      dialog_type = "Simple";
    };
    $('#tagsplugin_dialog_details')
    .load(
      foswiki.SCRIPTURL+"/view/"+foswiki.SYSTEMWEB+"/TagsPluginTagDetailsDialog?skin=text&cover=text&tag="+escape(tag)+"&tagweb="+escape(web)+"&tagtopic="+escape(topic)+"&dialog="+escape(dialog_type),
      null,
      function() {
        $("#tagsplugin_dialog_details").dialog("open");
        $("#tagsplugin_processing img").hide();
        /*
        TODO: hide those you cannot change
        $(".tagsplugin_dialog_editUserButton").each( function() {
                                                       var regexp = RegExp("\b"+foswiki.wikiName+"\b");
                                                       var groups = $('#tagsplugin_groups').text() + "," + $(this).attr("user");
                                                       if ( !regexp.test(groups) ) { $(this).hide(); };
                                                     } );
        */
        $(".tagsplugin_dialog_editUserButton:visible").bind(
          'click',
          function(event) {
            var tag    = $(event.target).attr("tag");
            var user   = $(event.target).attr("user");
            var public = $(event.target).closest("tr").find("input.tagsplugin_public_checkbox").is(":checked") ? "1" : "0";
            var groups = $.trim( $('#tagsplugin_groups').text() ).split(",");
            groups.push( user );

            // construct <select>
            var group_select = "<select>";
            if ( foswiki.wikiName != user ) { groups.push( foswiki.wikiName ) };
            for (var i=0; i < groups.length; i++) {
              var current_user = (user == groups[i]) ? "selected" : "";
              group_select += "<option "+current_user+">"+groups[i]+"</option>";
            };
            group_select += "</select>&nbsp;<img src='"+foswiki.PUBURL+"/"+foswiki.SYSTEMWEB+"/DocumentGraphics/choice-yes.gif' />";

            // replace owner with select-box
            $(event.target).closest('span')
            .html( group_select )
            .find("img")
            .bind(
              'click',
              { tag: tag, user: user, public: public },
              function(event) {
                var selection = $(event.target).closest("span").find("select");
                var tag     = event.data.tag;
                var user    = event.data.user;
                var public  = event.data.public;
                var newuser = selection.val();
                var item = foswiki.web+"."+foswiki.TOPIC;
                if ( user != newuser ) {
                  $("#tagsplugin_tagdetails_processing").show();
                  jQuery.tagsplugin.changeOwner(tag, public, { user:user, 
                                                               newuser:newuser, 
                                                               item:item
                                                             });
                } else {
                  foswiki.tag = tag; // SMELL
                  $("#tagsplugin_tagdetails_processing").show();
                  $(".tagsplugin_update_observer").trigger("tagsplugin_update");
                }
              }
            );
          } 
        );
      }
    );
  }

})(jQuery);
