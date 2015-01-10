package Threads::Action::ThankReply;

use strict;
use warnings;

use parent 'Tu::Action';

use Threads::DB::User;
use Threads::DB::Reply;
use Threads::DB::Thank;

sub run {
    my $self = shift;

    my $reply_id = $self->captures->{id};
    return $self->throw_not_found
      unless my $reply = Threads::DB::Reply->new(id => $reply_id)->load;

    my $user = $self->scope->user;

    my $count =
      Threads::DB::Thank->table->count(
        where => [reply_id => $reply->get_column('id')]);

    return $self->throw_not_found
      if $user->get_column('id') == $reply->get_column('user_id');

    my $thank = Threads::DB::Thank->find(
        first => 1,
        where => [
            user_id  => $user->get_column('id'),
            reply_id => $reply->get_column('id')
        ]
    );

    my $state;
    if ($thank) {
        $thank->delete;

        $state = 0;

        $count--;
    }
    else {
        Threads::DB::Thank->new(
            user_id  => $user->get_column('id'),
            reply_id => $reply->get_column('id')
        )->create;

        $count++;

        $state = 1;
    }

    $reply->set_column(thanks_count => $count);
    $reply->update;

    return {count => $count == 0 ? '': $count, state => $state}, type => 'json';
}

1;