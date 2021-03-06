package Threads::Action::Deregister;

use strict;
use warnings;

use parent 'Tu::Action';

use Threads::DB::User;
use Threads::DB::Confirmation;
use Threads::Action::TranslateMixin 'loc';
use Threads::Util qw(to_hex);

sub run {
    my $self = shift;

    return if $self->req->method eq 'GET';

    my $user = $self->env->{'tu.user'};

    my $confirmation = Threads::DB::Confirmation->new(
        user_id => $user->id,
        type    => 'deregister'
    )->create;

    my $email = $self->render(
        'email/deregistration_confirmation_required',
        layout => undef,
        vars   => {
            email => $user->email,
            token => to_hex $confirmation->token
        }
    );

    $self->mailer->send(
        headers => [
            To      => $user->email,
            Subject => $self->loc('Deregistration confirmation')
        ],
        body => $email
    );

    return $self->render(
        'deregistration_confirmation_needed',
        vars => {email => $user->email}
    );
}

sub mailer {
    my $self = shift;

    return $self->service('mailer');
}

1;
