//= require jquery-2.1.3.min.js
//= require sisyphus.min.js
//= require jquery.growl.js

// Polling for new posts every 2 minutes should be more than enough
// TODO: Not implemented yet
var pollFrequency = 120;
var polling = false;

// Keep track of if we're already loading some posts over AJAX or not
// TODO: Not implemented yet
var loading = false;

// Is the page visible? (That is, is the tab currently open?)
var pageVisible = true;

// Store info about the visit
// try {
//   localStorage['lastLoaded'] = new Date().getTime();
//   localStorage['views'] = localStorage['views'] || 0
//   localStorage['views']++
//   
//   // If the user has seen more than 5 pages on the site, they
//   // don't need to see a lot of the 'cruft'
//   if (parseInt(localStorage['visits']) > 5) {
//     $('BODY').addClass('expert');
//   }
// } catch(e) { }

// Puts a nice divider between posts of different dates, even if loaded dynamically
function doDateBreakLines() {
  var lastdoy = 0;
  $('section.posts article.post').each(function(i) {
    var thisdoy = $(this).data('doy');
    if (thisdoy != lastdoy) {
      lastdoy = thisdoy;
      if (!$(this).data('dateline')) {
        $(this).data('dateline', true);
        var timeEl = $(this).find('time').first();
        $(this).before("<h3 class='divider'><i class='fa fa-calendar-o'></i>&nbsp;&nbsp;" + timeEl.text() + "</h3>");
      }
      $('article.post time').hide();
    }
  });
}

// When the document is loaded and good to go, do a lotta stuff!
$(document).ready(function() {
  // Make sure all forms save their contents
  $('.postbox FORM').sisyphus({ autoRelease: false });

  // Deleting posts
  $('section.posts').on('click', '.tools A.delete', function(e) {
    var el = $(this).closest('article.post');
    var uid = el.data('uid');
    if (confirm('Delete this post?')) {
      $.ajax({
        type: "DELETE",
        url: base_url + "/post/" + uid,
        success: function(res) {
          el.hide();
          $.growl.notice({ message: "Post deleted" });
        }
      });
    }
    e.preventDefault();
  });

  // Deleting posts from within the post itself
  // This is getting a bit ugly, but hey ho, refactor later!
  $('BODY.post ARTICLE.post .tools A.delete').click(function(e) {
    var el = $(this).closest('article.post');
    var uid = el.data('uid');
    if (confirm('Delete this post?')) {
      $.ajax({
        type: "DELETE",
        url: base_url + "/post/" + uid,
        success: function(res) {
          window.location = base_url;
        }
      });
    }
    e.preventDefault();
  });  

  // Deleting comments
  $('section.comments').on('click', '.tools A.delete', function(e) {
    var el = $(this).closest('div.comment');
    var id = el.data('id');

    if (confirm('Delete this comment?')) {
      $.ajax({
        type: "DELETE",
        url: base_url + "/comment/" + id,
        success: function(res) {
          el.hide();
        }
      });
    }
    e.preventDefault();
    return false;
  });



  // When submitting a form, do lots of stuff..
  $('BUTTON.submit.comment, BUTTON.submit.post, BUTTON.preview.post').click(function(e) {
    var that = $(this);
    var data = that.closest('FORM').serialize();

    if ($(this).hasClass('preview')) {
      data += '&preview=true';
    }

    $.ajax({
             type: "POST",
             url: that.closest('FORM').attr('action'),
             data: data,
             success: function(res) {
               // Remove any errors showing on the form
               that.closest('FORM').find('.error').remove();
               that.closest('FORM').find('INPUT, TEXTAREA').removeClass('errored');

               // If there was a preview, show it
               if (res['preview']) {
                console.log('preview');
                 $('#preview').show();
                 $('#preview .title').html(res['preview']['title']);
                 $('#preview .content').html(res['preview']['content']);
                 return;
               }
               console.log('x');

               // If there were errors, show them
               if (res['errors']) {
                 res['errors'].forEach(function(err) {
                   var el = that.closest('FORM').find('[name=' + err[0] + ']');
                   el.addClass('errored');
                   el.after("<div class='error'>" + err[1] + "</div>");
                 });
               }

               // Redirect to a post that's just been created or edited
               if (res['redirect_to_post']) {
                 that.closest('FORM').sisyphus().manuallyReleaseData();
                 if (res['comment_id']) {
                   window.location.href = res['redirect_to_post'] + '?r=' + Math.floor(Math.random() * 100) + '#comment-' + res['comment_id'];
                 } else {
                   window.location.href = res['redirect_to_post']
                 }
               }

               // Redirect into the OAuth external authentication process
               if (res['redirect_to_oauth']) {
                 window.location = '/auth/' + res['redirect_to_oauth'];
               }
             }
           });
    e.preventDefault();
    return false;
  });

  // If the user hasn't seen the site's description bar before, show it
  if(!localStorage['seenDescription']) {
    localStorage['seenDescription'] = true;
    $('#sitedescription').show();
  }

  // $('#sitedescription').show();

  function showSubmitForm() {
    $('#sitedescription').hide();
    $('#submitform').show();
    window.scrollTo(0, 0);
    // TODO: Fixes an issue where scroll happens before box is drawn. Probably need to find a more elegant way to do this
    setTimeout("window.scrollTo(0, 0);", 70);
  }

  // If the user wants to write a post, show the form or head to the index page to show it there
  $('a.submit').click(function() {
    if ($('#submitform').length) {
      showSubmitForm();
    } else {
      window.location = "/#submitform";
    }
  });

  // Is the user trying to see the submission form? Show it
  if (window.location.hash && window.location.hash.substring(1) === 'submitform') {
    showSubmitForm();
  }

  // If specifically directed to a certain comment, make it flash a bit
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

  };

  // TODO: Add polling for new posts
  //       Once new posts are found, either notify the user or just add them on to the page

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

