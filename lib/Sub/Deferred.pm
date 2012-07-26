package Sub::Deferred;

use strict;
use warnings;

use Sub::Deferred::Promise;
use Sub::Deferred::Callbacks;

our $DEBUG   = 0;
our $VERSION = '0.01';

sub log {
    warn "[Sub::Deferred] $_[1]\n" if $DEBUG;
}

sub new {
    my ($package, $func) = @_;

    my $done_list = Sub::Deferred::Callbacks->new(once => 1, memory => 1);
    my $fail_list = Sub::Deferred::Callbacks->new(once => 1, memory => 1);

    my $prog_list = Sub::Deferred::Callbacks->new(memory => 1);

    my $list = {
        resolve => $done_list,
        reject  => $fail_list,
        notify  => $prog_list
    };

    my $deferred; $deferred = Sub::Deferred::Promise->new({
        done => sub { $done_list->add(@_) },
        fail => sub { $fail_list->add(@_) },
        progress   => sub { $prog_list->add(@_) },
        state      => "pending",
        is_resolved => sub { $done_list->fired },
        is_rejected => sub { $fail_list->fired },
        key_fire    => sub { my $key = shift; $list->{$key}->fire_with($deferred, @_) },
        key_fire_with => sub { my $key = shift; $list->{$key}->fire_with(@_) }
    });

    $deferred->done(
        sub { $_->{state} = 'resolved' },
        sub { $fail_list->disable },
        sub { $prog_list->lock; }
    )->fail(
        sub { $_->{state} = 'rejected' },
        sub { $done_list->disable },
        sub { $prog_list->lock }
    );

    $func->($deferred, $deferred) if $func && ref $func eq 'CODE';

    $deferred;
}

sub when {
    my $package = shift;
    my $args = \@_;

    my $length = my $count = my $p_count = @_;
    my $p_values = [$length];

    my $deferred = $package->new;
    my $promise  = $deferred->promise;

    my $resolve_fn = sub {
        my $i = shift;
        sub {
            my $value = shift;
            $args->[$i] = \@_;
            $deferred->resolve($args) unless --$count;
        };
    };

    my $progress_fn = sub {
        my $i = shift;
        sub {
            my $value = shift;
            $p_values->[$i] = \@_;
            $deferred->notify($promise, $p_values);
        };
    };

    if ($length > 1) {
        for my $i (0 .. ($length - 1)) {
            if ($args->[$i] && ref $args->[$i] eq 'Sub::Deferred::Promise') {
                $args->[$i]->promise->then(
                    $resolve_fn->($i),
                    $deferred->can('reject'),
                    $progress_fn->($i)
                );
            }
            else {
                --$count;
            }
        }
        $deferred->resolve($args) unless $count;
    }
    else {
        $deferred->resolve([]);
    }

    $promise;
}

1;
__END__

=head1 NAME

Sub::Deferred - ported from jQuery.Deferred

=head1 SYNOPSIS

  use Sub::Deferred;
  use AnyEvent;

  my $cv = AE::cv;
  my $def1 = Sub::Deferred->new;
  my $def2 = Sub::Deferred->new;
  my $def3 = Sub::Deferred->new;
  my $when = Sub::Deferred->when($def1, $def2, $def3);
  my $foo = 2;
  my $t1 = AE::timer 1, 0, sub {
      $foo *= 2;
      $def1->resolve;
  };
  my $t2 = AE::timer 2, 0, sub {
      $foo *= 2;
      $def2->resolve;
  };
  my $t3 = AE::timer 1, 0, sub {
      $foo *= 2;
      $def3->resolve;
  };
  $when->done(sub {
      $foo *= 3;
      $cv->send($foo);
  });

  print $cv->recv, "\n"; # => 48


=head1 DESCRIPTION

Sub::Deferred is

=head1 AUTHOR

Taiyoh Tanaka E<lt>sun.basix@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
