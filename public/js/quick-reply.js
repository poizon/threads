(function(){

    $('.quick-reply-form textarea, .quick-edit-form textarea').focus(function() {
       $(this).removeClass('error');
       $(this).next('div.error').hide();
    });

    $('.quick-reply-button').click(function() {
        var form = $(this).parent().find('.quick-reply-form');

        if (!form.css('display') || form.css('display') == 'none') {
            form.show();

            var textarea = form.find('textarea');

            var selection = window.getSelection().toString();
            if (selection) {
                selection = selection.replace(/^/gm, '> ');
                selection += "\n\n";
                textarea.val(selection);
            }

            textarea.focus();

            form.find('textarea').keydown(function (e) {
              if ((e.keyCode == 10 || e.keyCode == 13) && e.ctrlKey) {
                  e.preventDefault();

                  $(this).parent().parent().submit();
              }
            });
        }
        else {
            form.find('textarea').off('keydown');
            form.hide();
        }

        return false;
    });

    $('.quick-edit-button').click(function() {
        var form = $(this).parent().find('.quick-edit-form');

        if (!form.css('display') || form.css('display') == 'none') {
            form.show();
            form.find('textarea').focus();

            form.find('textarea').keydown(function (e) {
              if ((e.keyCode == 10 || e.keyCode == 13) && e.ctrlKey) {
                  e.preventDefault();

                  $(this).parent().parent().submit();
              }
            });
        }
        else {
            form.find('textarea').off('keydown');
            form.hide();
        }

        return false;
    });

    $('.index-sorting select').change(function() {
        $('.index-sorting form').submit();
        return false;
    });

    $('.markup-help-button').click(function() {
        var help = $(this).parent().find('.markup-help');
        if (!help.html().length) {
            var el = $('.markup-help-template').clone();
            help.html(el.html());
        }

        help.find('.markup-help-instance').toggle();
        return false;
    });

    function highightReply() {
        var hash = window.location.hash;
        if (hash) {
            var re = /reply-\d+/;
            var match = re.exec(hash);

            if (match && match.length) {
                var el = $('a[name=' + match[0] + ']').parent().parent().parent();

                el.css('backgroundColor', '#eee');
                setTimeout(function() {
                    el.css('backgroundColor', 'white');
                }, 500);
            }
        }
    }

    highightReply();
    $(window).bind('hashchange', function() {
        highightReply();
    });

    $('form.ajax').submit(function() {
        var form = $(this);
        var formData = form.serializeArray();
        $.ajax({
            type: 'POST',
            url: form.attr('action'),
            data: formData,
            success: function(data) {
                if (data.redirect) {
                    window.location = data.redirect;
                }
                else if (data.errors) {
                    for (var key in data.errors) {
                        var field = form.find('textarea[name='+key+']');

                        if (field.length) {
                            field.addClass('error');
                            if (!field.next('div.error').length) {
                                field.after('<div class="error"></div>');
                            }
                            field.next('div.error').html(data.errors[key]).show();
                        }
                    }
                }
                else {
                    form.find('input[name=update]').each(function() {
                        var value = $(this).attr('value');
                        var arr = value.split('=');

                        form.find(arr[0]).html(data[arr[1]]);
                    });

                    form.find('input[name=replace-class]').each(function() {
                        var value = $(this).attr('value');
                        var arr = value.split('=');

                        var classes = arr[1].split(',');

                        var from = classes[0];
                        var to = classes[1];

                        if (data.state) {
                            from = classes[1];
                            to = classes[0];
                        }

                        form.find(arr[0]).removeClass(from).addClass(to);
                    });
                }
            },
            failure: function(errMsg) {}
        });

        return false;
    });

    $('.reply').mouseover(function() {
        //$(this).find('.reply-controls').css('visibility', 'visible');
    });

    $('.reply').mouseout(function() {
        //$(this).find('.reply-controls').css('visibility', 'hidden');
    });

})();
