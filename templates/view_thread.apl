% $helpers->assets->require('/autosize/jquery.autosize.min.js');
% $helpers->assets->require('/js/quick-reply.js');
% $helpers->meta->set(title => $thread->{title});

<div class="grid-100">

    %== $helpers->displayer->render('include/thread', thread => $thread, view => 1);

    % if ($helpers->acl->is_user) {
    %== $helpers->displayer->render('include/thread-controls', thread => $thread);
    % }

    <div class="thread-similar">
    % my @similar = $helpers->thread->similar($thread);
    % if (@similar) {
        <strong><%= loc('Similar threads') %></strong>
    <ul>
    % foreach my $similar_thread (@similar) {
        <li><a href="<%= $helpers->url->view_thread(id => $similar_thread->{id}, slug => $similar_thread->{slug}) %>"><%= $similar_thread->{title} %></a></li>
    % }
    </ul>
    % }
    </div>

    <div class="replies">
    <ul class="tree">
    % my $level = 0;
    % foreach my $reply ($helpers->reply->find_by_thread($thread)) {
        % $reply->{level} = 3 if $reply->{level} > 3;
        % if ($reply->{level} > $level) {
            <li class="tree-el">
                <ul class="tree-el">
                    <li class="tree-el">
        % } elsif ($reply->{level} < $level) {
            % for (1 .. $level - $reply->{level}) {
            </ul>
            </li>
            % }

            <li class="tree-el">
        % } else {
            <li class="tree-el">
        % }

        <div class="reply">

            %== $helpers->displayer->render('include/reply-meta', reply => $reply, thread => $thread);
            <div class="reply-content">
                <%== $helpers->markup->render($reply->{content}) %>
            </div>

            %== $helpers->displayer->render('include/reply-thank', thread => $thread, reply => $reply);

            %== $helpers->displayer->render('include/reply-controls', thread => $thread, reply => $reply);

            <div class="clear"></div>
        </div>

        </li>

        % $level = $reply->{level};
    % }
    </ul>
    </div>

    % if ($helpers->acl->is_anon) {
    <div class="not-user-notice">
        <%== loc('To reply to this thread login or register') %>.

        <div>
            <a href="<%= $helpers->url->login %>"><%= loc('Login') %></a> <%= loc('or') %> <a href="<%= $helpers->url->register %>"><%= loc('Sign up') %></a>
        </div>

    </div>
    % }

    %== $helpers->displayer->render('include/markup-help');
</div>
