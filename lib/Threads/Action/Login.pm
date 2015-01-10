package Threads::Action::Login;

use strict;
use warnings;

use parent 'Threads::Action::FormBase';

use Threads::DB::User;
use Threads::DB::Nonce;

sub build_validator {
    my $self = shift;

    my $validator = $self->SUPER::build_validator;

    $validator->add_field('email');
    $validator->add_field('password');

    $validator->add_rule('email', 'Email');

    return $validator;
}

sub validate {
    my $self = shift;
    my ($validator, $params) = @_;

    my $user = Threads::DB::User->new(email => $params->{email})->load;

    if (!$user) {
        $validator->add_error(email => $self->loc('Unknown credentials'));
        return;
    }

    if (!$user->check_password($params->{password})) {
        $validator->add_error(email => $self->loc('Unknown credentials'));
        return;
    }

    if ($user->get_column('status') eq 'new') {
        $validator->add_error(email => $self->loc('Account not activated'));
        return;
    }

    if ($user->get_column('status') eq 'blocked') {
        $validator->add_error(email => $self->loc('Account blocked'));
        return;
    }

    if ($user->get_column('status') ne 'active') {
        $validator->add_error(email => $self->loc('Account not active'));
        return;
    }

    $self->{user} = $user;

    return 1;
}

sub submit {
    my $self = shift;
    my ($params) = @_;

    my $nonce =
      Threads::DB::Nonce->new(user_id => $self->{user}->get_column('id'))->create;

    $self->scope->auth->login($self->env, {id => $nonce->get_column('id')});

    return $self->redirect('index');
}

1;
