//= require jquery-2.1.3.min.js
//= require sisyphus.min.js

// Polling for new posts every 2 minutes should be more than enough
// TODO: Not implemented yet
var pollFrequency = 120;
var polling = false;

// Keep track of if we're already loading some posts over AJAX or not
// TODO: Not implemented yet
var loading = false;

// Is the page visible? (That is, is the tab currently open?)
var pageVisible = true;

// Puts a nice divider between posts of different dates, even if loaded dynamically
function doDateBreakLines() {
  var lastdoy = 0;
  $('section.posts article.post').each(function(i) {
    var thisdoy = $(this).data('doy');
    /* if (i == 0) {
      lastdoy = thisdoy;

    } else { */
      if (thisdoy != lastdoy) {
        lastdoy = thisdoy;
        if (!$(this).data('dateline')) {
          $(this).data('dateline', true);
          var timeEl = $(this).find('time').first();
          $(this).before("<h3 class='divider'><i class='fa fa-calendar-o'></i>&nbsp;&nbsp;" + timeEl.text() + "</h3>");
        }
        $('article.post time').hide();
      }
    /*} */
  });
}

// When the document is loaded and good to go, do a lotta stuff!
$(document).ready(function() {

  //// if we're going thin from the start, make the sticky header permanent
  //if (window.matchMedia("(max-width: 620px)").matches) {
  //  $("body").addClass("fix-header permanent");
  //}

  //// sticky header
  //$(window).scroll(function() {
  //  if ($(window).scrollTop() > 74) {
  //    $("body").addClass("fix-header");
  //  } else if (!$("body").is('.fix-header.permanent')) {
  //    $("body").removeClass("fix-header");
  //  }
  //});
  $('.postbox FORM').sisyphus({ autoRelease: false });

  $('BUTTON.submit.comment, BUTTON.submit.post').click(function() {
    var that = $(this);
    $.ajax({
             type: "POST",
             url: $('DIV.postbox FORM').attr('action'),
             data: $('DIV.postbox FORM').serialize(),
             success: function(res) {
               console.log(res);
               that.closest('FORM').find('.error').remove();
               that.closest('FORM').find('INPUT, TEXTAREA').removeClass('errored');
               if (res['errors']) {
                 res['errors'].forEach(function(err) {
                   var el = that.closest('FORM').find('[name=' + err[0] + ']');
                   el.addClass('errored');
                   el.after("<div class='error'>" + err[1] + "</div>");
                 });
                 //that.closest('FORM').find('.')
               }
               if (res['redirect_to_post']) {
                 that.closest('FORM').sisyphus().manuallyReleaseData();
                 if (res['comment_id']) {
                   window.location.href = res['redirect_to_post'] + '?r=' + Math.floor(Math.random() * 100) + '#comment-' + res['comment_id'];
                 } else {
                   window.location.href = res['redirect_to_post']
                 }
               }
               if (res['redirect_to_oauth']) {
                 window.location = '/auth/' + res['redirect_to_oauth'];
               }
             }
           });
    return false;
  });

  // If there's a form in local storage, it was probably unsubmitted, so repopulate the form, if any
  //if (localStorage['formData']) {
  //  // credit to http://stackoverflow.com/questions/9035825/read-from-serialize-to-populate-form for this
  //  $.each(localStorage['formData'].split('&'), function (i, el) {
  //    var vals = el.split('=');
  //    $("FORM [name='" + vals[0] + "']").val(decodeURIComponent(vals[1]).replace(/\+/g, ' '));
  //  });
  //}

  // If the user hasn't seen the site's description bar before, show it
  if(!localStorage['seenDescription']) {
    localStorage['seenDescription'] = true;
    $('#sitedescription').show();
  }

  function showSubmitForm() {
    $('#sitedescription').hide();
    $('#submitform').show();
    window.scrollTo(0, 0);
    // TODO: Fixes an issue where scroll happens before box is drawn. Probably need to find a more elegant way to do this
    setTimeout("window.scrollTo(0, 0);", 50);
  }

  $('a.submit').click(function() {
    if ($('#submitform').length) {
      showSubmitForm();
    } else {
      window.location = "/#submitform";
    }
  });

  if (window.location.hash && window.location.hash.substring(1) === 'submitform') {
    showSubmitForm();
  }

  if (window.location.hash && window.location.hash.match(/comment/)) {
    $(window.location.hash + ' .content').addClass('flashing');
  }

  // If we're on the index page and have a list of posts..
  if ($('body.index section.posts').length) {
    // We're able to poll
    polling = true;

    // Do the initial date dividers between posts of different dates
    doDateBreakLines();

    // prevent widows in titles - courtesy of Chris Coyier and stolen from http://css-tricks.com/preventing-widows-in-post-titles/
    $("h1 a").each(function() {
      var wordArray = $(this).text().split(" ");
      if (wordArray.length > 1) {
        wordArray[wordArray.length-2] += "&nbsp;" + wordArray[wordArray.length-1];
        wordArray.pop();
        $(this).html(wordArray.join(" "));
      }
    });

    // And if we're scrolling..
    $(window).scroll(function() {
      // And we've scrolled to the bottom of the screen AND we're not already loading posts over AJAX..
      if (($(window).scrollTop() > $(document).height() - $(window).height() - 16) && !loading) {
        // Then work out which page of posts we need to load
        loading = true;
        var bottomMostPage = $('section.posts article.post').last().data('page');

        // Show the 'loading' message and hide the 'next page' link
        $('#loading').show();
        $('.nextpage').hide();

        // Grab the next page of posts
        $.ajax({
          url: "?page=" + (bottomMostPage + 1),
          type: "GET",
          success: function(html) {
            // We've stopped loading now, so hide the loading message and add the posts to the list
            // TODO: Running into some issues here when going back then forward again
            //history.replaceState({ page: bottomMostPage + 1 }, '', "?page=" + (bottomMostPage + 1));
            loading = false;
            $('#loading').hide();
            $('body.index section.posts').append(html);
            doDateBreakLines();
          }
        });
      }
    });

    // Mark posts as read if we've already 'seen' them
    // TODO: Come up with a better mechanism for this, perhaps if we scroll past a certain post?
    // $('section.posts article.post').each(function() {
    //   if (localStorage['lastLoaded'] && (localStorage['lastLoaded'] > $(this).data('timestamp'))) {
    //     $(this).addClass('read');
    //   }
    // });

    // Store the time visited
    localStorage['lastLoaded'] = new Date().getTime();
  };

  // TODO: Add polling for new posts
  //       Once new posts are found, either notify the user or just add them on to the page
  //

  // If the tab is hidden (this is the Page Visibility API at work) we don't need to poll so much
  document.addEventListener("visibilitychange", function() {
    if (document.hidden) {
      // If the tab is hidden, poll every 5 minutes instead
      pollFrequency = 300;
      pageVisible = false;
    } else {
      pollFrequency = 120;
      pageVisible = true;
    }
  });
});
