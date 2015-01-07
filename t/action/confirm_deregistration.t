use strict;
use warnings;

use Test::More;
use Test::Fatal;
use TestLib;
use TestDB;
use TestRequest;

use HTTP::Request::Common;
use Toks::DB::User;
use Toks::DB::Confirmation;
use Toks::Action::ConfirmDeregistration;

subtest 'return 404 when confirmation token not found' => sub {
    my $action = _build_action(captures => {});

    my $e = exception { $action->run };
    isa_ok($e, 'Tu::X::HTTP');
    is $e->code, '404';
};

subtest 'return 404 when confirmation not found' => sub {
    TestDB->setup;

    my $action = _build_action(captures => {token => '123'});

    my $e = exception { $action->run };
    isa_ok($e, 'Tu::X::HTTP');
    is $e->code, '404';
};

subtest 'return 404 when user not found' => sub {
    TestDB->setup;

    my $confirmation = Toks::DB::Confirmation->new(user_id => 123)->create;
    my $action =
      _build_action(captures => {token => $confirmation->get_column('token')});

    my $e = exception { $action->run };
    isa_ok($e, 'Tu::X::HTTP');
    is $e->code, '404';
};

subtest 'remove user' => sub {
    TestDB->setup;

    my $user = Toks::DB::User->new(email => 'foo@bar.com')->create;
    my $confirmation =
      Toks::DB::Confirmation->new(user_id => $user->get_column('id'))->create;
    my $action =
      _build_action(captures => {token => $confirmation->get_column('token')});

    $action->run;

    ok !$user->load;
};

subtest 'delete confirmation' => sub {
    TestDB->setup;

    my $user = Toks::DB::User->new(email => 'foo@bar.com')->create;
    my $confirmation =
      Toks::DB::Confirmation->new(user_id => $user->get_column('id'))->create;
    my $action =
      _build_action(captures => {token => $confirmation->get_column('token')});

    $action->run;

    ok !$confirmation->load;
};

sub _build_action {
    my (%params) = @_;

    my $env = TestRequest->to_env(%params);

    my $action = Toks::Action::ConfirmDeregistration->new(env => $env);
    $action = Test::MonkeyMock->new($action);
    $action->mock(render => sub { '' });

    return $action;
}

done_testing;