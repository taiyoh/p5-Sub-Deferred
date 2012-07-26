package Sub::Deferred::Promise;

use strict;
use warnings;

use Sub::Deferred;

sub log { Sub::Deferred->log(splice @_, 1) if $Sub::Deferred::DEBUG }

sub new {
    my ($package, $obj) = @_;
    $obj ||= {};
    bless $obj, $package;
}

sub done { my $self = shift; $self->{done}->(@_); $self }
sub fail { my $self = shift; $self->{fail}->(@_); $self }
sub progress { my $self = shift; $self->{progress}->(@_); $self }
sub state { shift->{state} }
sub is_resolved { shift->{is_resolved}->() }
sub is_rejected { shift->{is_rejected}->() }

sub resolve { my $self = shift; $self->{key_fire}->('resolve', @_); $self }
sub reject  { my $self = shift; $self->{key_fire}->('reject', @_); $self }
sub notify  { my $self = shift; $self->{key_fire}->('notify', @_); $self }

sub resolve_with { my $self = shift; $self->{key_fire_with}->('resolve', @_); $self }
sub reject_with  { my $self = shift; $self->{key_fire_with}->('reject', @_); $self }
sub notify_with  { my $self = shift; $self->{key_fire_with}->('notify', @_); $self }

sub then {
    my $self = shift;
    my ($done_callbacks, $fail_callbacks, $progress_callbacks) = @_;

    $done_callbacks ||= sub {};
    $fail_callbacks ||= sub {};
    $progress_callbacks ||= sub {};

    $done_callbacks = [$done_callbacks] unless ref $done_callbacks eq 'ARRAY';
    $fail_callbacks = [$fail_callbacks] unless ref $fail_callbacks eq 'ARRAY';
    $progress_callbacks = [$progress_callbacks] unless ref $progress_callbacks eq 'ARRAY';

    $self->done(@$done_callbacks)
         ->fail(@$fail_callbacks)
         ->progress(@$progress_callbacks);
}

sub always { shift->done(@_)->fail(@_) }

sub pipe {
    my $self = shift;
    my ($fn_done, $fn_fail, $fn_progress) = @_;

    Sub::Deferred->new(sub {
        my $new_self = shift;
        my %data = (
            done => [$fn_done, 'resolve'],
            fail => [$fn_fail, 'reject'],
            progress => [$fn_progress, 'notify']
        );
        for my $handler (qw/done fail progress/) {
            my $d = $data{$handler};
            my ($fn, $action) = @$d;
            my $returned;
            if (ref $fn eq 'CODE') {
                $self->$handler(sub {
                    local $_ = $self;
                    $returned = $fn->($self, @_);
                    if (ref $returned eq 'Sub::Deferred::Promise') {
                        $returned->promise->then(
                            $new_self->can('resolve'),
                            $new_self->can('reject'),
                            $new_self->can('notify')
                        )
                    }
                    else {
                        if (my $proc = $new_self->can("${action}_with")) {
                            $proc->($new_self, $new_self eq $self ? $new_self : $self, [ $returned ]);
                        }
                    }
                });
            }
            else {
                $self->$handler($new_self->can($action));
            }
        }
    });
}

sub promise {
    my ($self, $obj) = @_;
    $obj ||= {};

    for my $key (qw/done fail progress state is_resolved is_rejected/) {
        $obj->{$key} = $self->{$key};
    }

    for my $key (qw/key_fire key_fire_with/) {
        $obj->{$key} = sub { $self->log("invalid call: $_[0]") };
    }

    __PACKAGE__->new($obj);
}

1;
