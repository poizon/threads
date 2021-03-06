use strict;
use warnings;

use Test::More;
use Test::Fatal;
use TestLib;
use TestDB;
use TestRequest;

use HTTP::Request::Common;
use Threads::DB::Thread;
use Threads::Action::ViewThread;

subtest 'throws 404 when no thread' => sub {
    TestDB->setup;

    my $action = _build_action(captures => {});

    my $e = exception { $action->run };

    is $e->code, 404;
};

subtest 'returns nothing on success' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;

    my $action = _build_action(captures => {id => $thread->id});

    $action->run;

    ok $action->scope->displayer->vars->{thread};
};

subtest 'increments view count' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;

    my $action = _build_action(captures => {id => $thread->id});

    $action->run;

    $thread->load;
    is $thread->views_count, 1;
};

subtest 'not increments view count when same user' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;
    my $user =
      Threads::DB::User->new(email => 'foo@bar.com', password => 'silly')->create;

    my $action = _build_action(
        captures  => {id => $thread->id},
        'tu.user' => $user
    );
    $action->run;

    $action = _build_action(
        captures  => {id => $thread->id},
        'tu.user' => $user
    );
    $action->run;

    $thread->load;
    is $thread->views_count, 1;
};

subtest 'increments view count when same user but another day' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;
    my $user =
      Threads::DB::User->new(email => 'foo@bar.com', password => 'silly')->create;

    my $action = _build_action(
        captures  => {id => $thread->id},
        'tu.user' => $user
    );
    $action->run;

    Threads::DB::View->table->update(set => [created => '123']);

    $action = _build_action(
        captures  => {id => $thread->id},
        'tu.user' => $user
    );
    $action->run;

    $thread->load;
    is $thread->views_count, 2;
};

subtest 'increments view count when another user agent' => sub {
    TestDB->setup;

    my $thread = Threads::DB::Thread->new(user_id => 1)->create;
    my $user =
      Threads::DB::User->new(email => 'foo@bar.com', password => 'silly')->create;

    my $action = _build_action(
        req => GET('/', 'User-Agent' => 'one'),
        captures => {id => $thread->id}
    );
    $action->run;

    $action = _build_action(
        req => GET('/', 'User-Agent' => 'two'),
        captures => {id => $thread->id}
    );
    $action->run;

    $thread->load;
    is $thread->views_count, 2;
};

sub _build_action {
    my (%params) = @_;

    my $env = $params{env} || TestRequest->to_env(%params);

    my $action = Threads::Action::ViewThread->new(env => $env);

    return $action;
}

done_testing;
