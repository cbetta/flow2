// Polling for new posts every 2 minutes should be more than enough
var pollFrequency = 120;
var polling = false;

// Is the page visible? (That is, is the tab currently open?)
var pageVisible = true;

// Keep track of if we're already loading some posts over AJAX or not
var loading = false;

$(document).ready(function() {
  $(window).scroll(function() {
    if ($(window).scrollTop() > 100) {
      $("body").addClass("fix-header");
    } else {
      $("body").removeClass("fix-header");
    }
  });

  // If we're on the index page and have a list of posts..
  if ($('body.index section.posts').length) {
    // We're able to poll
    polling = true;

    // And if we're scrolling..
    $(window).scroll(function() {
      // And we've scrolled to the bottom of the screen AND we're not already loading posts over AJAX..
      if (($(window).scrollTop() > $(document).height() - $(window).height() - 2) && !loading) {
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
