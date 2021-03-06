use strict;
use warnings;

use Test::More;
use Test::Fatal;
use TestLib;
use TestDB;
use TestRequest;

use HTTP::Request::Common;
use Threads::DB::User;
use Threads::DB::Thread;
use Threads::DB::Reply;
use Threads::DB::Subscription;
use Threads::DB::Notification;
use Threads::Action::CreateReply;

subtest 'returns 404 when unknown thread' => sub {
    TestDB->setup;

    my $action = _build_action(req => POST('/' => {}), captures => {});

    my $e = exception { $action->run };

    is $e->code, 404;
};

subtest 'returns 404 when unknown to' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;
    my $action = _build_action(
        req      => POST('/?to=123' => {}),
        captures => {id             => $thread->id}
    );

    my $e = exception { $action->run };

    is $e->code, 404;
};

subtest 'shows errors' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;
    my $action = _build_action(
        req      => POST('/' => {}),
        captures => {id      => $thread->id}
    );

    my $res = $action->run;

    like $res->body, qr/errors/;
};

subtest 'shows errors when limits' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(user_id => $user->id)->create;

    my $services = _mock_services(config => {limits => {replies => {60 => 5}}});
    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user,
        services  => $services
    );

    $action->run for 1 .. 10;

    is(Threads::DB::Reply->table->count, 5);
    is $action->vars->{errors}->{content}, 'Replying too often';
};

subtest 'creates reply with correct params' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(user_id => $user->id)->create;

    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    my $reply = Threads::DB::Reply->find(first => 1);

    ok $reply;
    is $reply->user_id,   $user->id;
    is $reply->thread_id, $thread->id;
    is $reply->content,   'bar';
};

subtest 'creates reply with correct params when parent present' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(user_id => $user->id)->create;
    my $parent = Threads::DB::Reply->new(
        user_id   => $user->id,
        thread_id => $thread->id
    )->create;

    my $action = _build_action(
        req => POST(
            '/?to=' . $parent->id => {content => 'bar'}
        ),
        captures  => {id => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    my $reply =
      Threads::DB::Reply->find(first => 1, order_by => [id => 'DESC']);

    is $reply->parent_id, $parent->id;
};

subtest 'updates replies_count in thread' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(user_id => $user->id)->create;

    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    $thread->load;

    is $thread->replies_count, 1;
};

subtest 'updates last_activity in thread' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(
        user_id       => $user->id,
        last_activity => '123'
    )->create;
    my $last_activity = $thread->last_activity;

    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    $thread->load;

    isnt $thread->last_activity, $last_activity;
};

subtest 'redirects to thread view' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(user_id => $user->id)->create;

    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user
    );
    $action->mock('url_for');

    my ($res) = $action->run;

    my ($name) = $action->mocked_call_args('url_for');
    is $name, 'view_thread';

    like $res->body, qr/redirect/;
};

subtest 'does not notify thread author when same replier' => sub {
    TestDB->setup;

    my $user = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread = Threads::DB::Thread->new(user_id => $user->id)->create;
    Threads::DB::Subscription->new(
        user_id   => $user->id,
        thread_id => $thread->id
    )->create;

    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    ok !Threads::DB::Notification->find(first => 1);
};

subtest 'notify subscribed users' => sub {
    TestDB->setup;

    my $thread_author = Threads::DB::User->new(
        name     => 'thread_author',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread =
      Threads::DB::Thread->new(user_id => $thread_author->id)->create;
    Threads::DB::Subscription->new(
        user_id   => $thread_author->id,
        thread_id => $thread->id
    )->create;

    my $user2 = Threads::DB::User->new(
        name     => 'user2',
        email    => 'foo2@bar.com',
        password => 'bar'
    )->create;
    Threads::DB::Subscription->new(
        user_id   => $user2->id,
        thread_id => $thread->id
    )->create;

    my $action = _build_action(
        req       => POST('/' => {content => 'bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user2
    );

    $action->run;

    my $reply = Threads::DB::Reply->find(first => 1);
    my $notification = Threads::DB::Notification->find(first => 1);

    is(Threads::DB::Notification->table->count, 1);

    ok $notification;
    is $notification->user_id,  $thread_author->id;
    is $notification->reply_id, $reply->id;
};

subtest 'notify parent reply user' => sub {
    TestDB->setup;

    my $thread_author = Threads::DB::User->new(
        name     => 'thread_author',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread =
      Threads::DB::Thread->new(user_id => $thread_author->id)->create;

    my $user = Threads::DB::User->new(
        name     => 'user',
        email    => 'foo2@bar.com',
        password => 'bar'
    )->create;

    my $parent_reply = Threads::DB::Reply->new(
        thread_id => $thread->id,
        user_id   => $user->id
    )->create;

    my $user2 = Threads::DB::User->new(
        name     => 'user2',
        email    => 'foo3@bar.com',
        password => 'bar'
    )->create;

    my $action = _build_action(
        req       => POST('/?to=' . $parent_reply->id => {content => 'bar'}),
        captures  => {id                              => $thread->id},
        'tu.user' => $user2
    );

    $action->run;

    my $reply =
      Threads::DB::Reply->find(first => 1, order_by => [id => 'DESC']);
    my $notification = Threads::DB::Notification->find(first => 1);

    is(Threads::DB::Notification->table->count, 1);

    ok $notification;
    is $notification->user_id,  $user->id;
    is $notification->reply_id, $reply->id;
};

subtest 'not notify parent reply user when same user' => sub {
    TestDB->setup;

    my $thread_author = Threads::DB::User->new(
        name     => 'thread_author',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread =
      Threads::DB::Thread->new(user_id => $thread_author->id)->create;

    my $user = Threads::DB::User->new(
        name     => 'user',
        email    => 'foo2@bar.com',
        password => 'bar'
    )->create;

    my $parent_reply = Threads::DB::Reply->new(
        thread_id => $thread->id,
        user_id   => $user->id
    )->create;

    my $action = _build_action(
        req       => POST('/?to=' . $parent_reply->id => {content => 'bar'}),
        captures  => {id                              => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    my $reply =
      Threads::DB::Reply->find(first => 1, order_by => [id => 'DESC']);
    my $notification = Threads::DB::Notification->find(first => 1);

    is(Threads::DB::Notification->table->count, 0);
};

subtest 'deletes notifications to parent reply' => sub {
    TestDB->setup;

    my $thread_author = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread =
      Threads::DB::Thread->new(user_id => $thread_author->id)->create;

    my $other_user =
      TestDB->create('User', name => 'other_user', email => 'foo2@bar.com');

    my $parent_reply = Threads::DB::Reply->new(
        thread_id => $thread->id,
        user_id   => $other_user->id
    )->create;

    my $user = Threads::DB::User->new(
        name     => 'user',
        email    => 'foo3@bar.com',
        password => 'bar'
    )->create;

    TestDB->create(
        'Notification',
        user_id  => $user->id,
        reply_id => $parent_reply->id
    );

    my $action = _build_action(
        req       => POST('/?to=' . $parent_reply->id => {content => 'bar'}),
        captures  => {id                              => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    ok !TestDB->build('Notification')->find(
        first => 1,
        where => [user_id => $user->id, reply_id => $parent_reply->id]
    );
};

subtest 'creates notifications for mentioned users' => sub {
    TestDB->setup;

    my $thread_author = Threads::DB::User->new(
        name     => 'foo',
        email    => 'foo@bar.com',
        password => 'bar'
    )->create;
    my $thread =
      Threads::DB::Thread->new(user_id => $thread_author->id)->create;

    my $user = Threads::DB::User->new(
        name     => 'user',
        email    => 'foo3@bar.com',
        password => 'bar'
    )->create;

    my $other_user = Threads::DB::User->new(
        name     => 'other_user',
        email    => 'foo4@bar.com',
        password => 'bar'
    )->create;

    my $action = _build_action(
        req       => POST('/' => {content => '@other_user bar'}),
        captures  => {id      => $thread->id},
        'tu.user' => $user
    );

    $action->run;

    my $notification = TestDB->build('Notification')->find(
        first => 1,
        where => [user_id => $other_user->id]
    );
    ok $notification;
};

sub _mock_services {
    my (%params) = @_;

    my $services = Test::MonkeyMock->new;
    $services->mock(
        service => sub { $params{config} || {} },
        when => sub { $_[1] eq 'config' }
    );
    return $services;
}

sub _build_action {
    my (%params) = @_;

    my $env = $params{env} || TestRequest->to_env(%params);

    my $action = Threads::Action::CreateReply->new(
        env      => $env,
        services => $params{services} || _mock_services()
    );
    $action = Test::MonkeyMock->new($action);

    return $action;
}

done_testing;
