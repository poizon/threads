package Toks::Helper::User;

use strict;
use warnings;

use parent 'Tu::Helper';

use Toks::DB::User;

sub display_name {
    my $self = shift;
    my ($user) = @_;

    return '' unless $user;

    return '<strike>deleted</strike>' if $user->{status} eq 'deleted';

    if (my $name = $user->{name}) {
        $name =~ s{&}{&amp;}g;
        $name =~ s{>}{&gt;}g;
        $name =~ s{<}{&lt;}g;
        $name =~ s{"}{&quot;}g;
        return $name;
    }

    return 'User' . $user->{id};
}

sub count {
    my $self = shift;
    my (%params) = @_;

    return Toks::DB::User->table->count(where => [status => 'active']);
}

1;
