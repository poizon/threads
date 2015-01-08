package Toks::Action::Settings;

use strict;
use warnings;

use parent 'Toks::Action::FormBase';

use Toks::DB::User;
use Toks::Action::TranslateMixin 'loc';

sub build_validator {
    my $self = shift;

    my $validator = $self->SUPER::build_validator;

    $validator->add_optional_field('name');
    $validator->add_optional_field('email_notifications');

    return $validator;
}

sub validate {
    my $self = shift;
    my ($validator, $params) = @_;

    my $user = $self->scope->user;

    if ($params->{name}) {
        my $exists = Toks::DB::User->find(
            first => 1,
            where => [
                id   => {'!=' => $user->get_column('id')},
                name => $params->{name}
            ]
        );

        if ($exists) {
            $validator->add_error(name => $self->loc('Name already exists'));
            return 0;
        }
    }

    return 1;
}

sub submit {
    my $self = shift;
    my ($params) = @_;

    my $user = $self->env->{'tu.user'};

    $user->set_columns(%$params);
    $user->update;

    return $self->redirect('index');
}

1;
