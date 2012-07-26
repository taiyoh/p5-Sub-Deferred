package Sub::Deferred::Callbacks;

use strict;
use warnings;

# from: http://addyosmani.com/blog/jquery-1-7s-callbacks-feature-demystified/
# Supported Flags
#   "once" – ensure the callback list can only be called once
#   "memory" – ensure if the list was already fired, adding more callbacks will have it called with the latest fired value
#   "unique" – ensure a callback can only be added to the list once
#   "stop_on_false" – interrupt callings when a particular callback returns false

sub log {
    require Sub::Deferred;
    Sub::Deferred->log(splice @_, 1);
}

sub new {
    my ($package, %flags) = @_;

    my $self = bless {
        _list  => [],
        _stack => [],
        _memory => undef,
        _firing => undef,
        _firing_start => undef,
        _firing_length => undef,
        _firing_index => undef,
        _flags => \%flags
    }, $package;

    $self->{_add} = sub {
        for my $elem (@_) {
            my $ref = ref $elem;
            if ($ref eq 'ARRAY') {
                $self->log("argument is ARRAY object. rerotate");
                $self->{_add}->(@$elem);
            }
            elsif ($ref eq 'CODE') {
                if (!$self->{_flags}{unique} || !$self->has($elem)) {
                    $self->log("register callback function");
                    push @{ $self->{_list} }, $elem;
                }
            }
        }
    };

    $self->{_fire} = sub {
        my ($context, $args) = @_;

        $args = [] if !$args || ref $args ne 'ARRAY';

        $self->{_firing} = 1;
        $self->{_memory} = !$self->{_flags}{memory} || [$context, $args];
        $self->log("no set _firing_start") unless $self->{_firing_start};
        $self->{_firing_index} = $self->{_firing_start} || 0;
        $self->{_firing_start} = 0;
        $self->{_firing_length} = scalar @{ $self->{_list} };
        my $executable = ref $self->{_list} eq 'ARRAY';

        if ($executable) {
            for (; $self->{_firing_index} < $self->{_firing_length}; ++$self->{_firing_index}) {
                local $_ = $context;
                $self->log("fire => ". $self->{_firing_index} . " in " . $self->{_firing_length});
                if (!$self->{_list}->[ $self->{_firing_index} ]->($context, $args) && $self->{_flags}{stop_on_false}) {
                    $self->log("false detected. halt.");
                    $self->{_memory} = 1; # mark as halted
                    last;
                }
            }
        }

        $self->{_firing} = 0;

        if ($executable) {
            if (!$self->{_flags}{once}) {
                if (scalar(@{ $self->{_stack} })) {
                    $self->log("stack exists.");
                    $self->{_memory} = shift @{ $self->{_stack} };
                    $self->fire_with(@{ $self->{_memory} });
                }
                $self->{_firing_start} = scalar @{ $self->{_list} };
            } elsif ($self->{_memory} eq 1) {
                $self->disable;
            }
            else {
                $self->empty;
            }
        }
    };

    $self
}

sub add {
    my $self = shift;

    return $self unless ref $self->{_list} eq 'ARRAY';

    my $length = scalar @{ $self->{_list} };
    $self->{_add}->(@_);

    if ($self->{_firing}) {
        $self->{_firing_length} = $length;
    }
    elsif ($self->{_memory} && $self->{_memory} ne 1) {
        $self->log("add: memory exists. fire, ${length}");
        $self->{_firing_start} = $length;
        $self->{_fire}->(@{ $self->{_memory} });
    }

    $self
}

sub remove {
    my $self = shift;

    return $self unless ref $self->{_list} eq 'ARRAY';

    my $length = scalar @{ $self->{_list} };
    for my $arg (@_) {
        $self->{_list} = [ grep { $_ ne $arg } @{ $self->{_list} } ];
        if ($length ne scalar(@{ $self->{_list} })) {
            $length = scalar(@{ $self->{_list} });
            if ($self->{_firing}) {
                if ($self->{_firing_length} && $length <= $self->{_firing_length}) {
                    --$self->{_firing_length};
                    --$self->{_firing_index} if $self->{_firing_index} && $length <= $self->{_firing_index};
                }
            }
            last if $self->{_flags}{unique};
        }
    }

    $self;
}

sub has {
    my ($self, $fn) = @_;

    return 0 unless ref $self->{_list} eq 'ARRAY';

    for my $f (@{ $self->{_list} }) {
        return 1 if $fn eq $f;
    }

    0
}

sub empty {
    my $self = shift;

    $self->{_list} = [];
    $self->log("empty list");

    $self
}

sub disable {
    my $self = shift;

    $self->log("make disable");
    $self->{_list} = $self->{_memory} = $self->{_stack} = undef;

    $self
}

sub disabled { ref shift->{_list} ne 'ARRAY' }

sub lock {
    my $self = shift;

    $self->log("make lock");
    $self->{_stack} = undef;
    $self->disable if !$self->{_memory} || $self->{_memory} eq 1;

    $self
}

sub locked { ref shift->{_stack} ne 'ARRAY' }

sub fire_with {
    my ($self, $context, $args) = @_;

    return $self unless ref $self->{_stack} eq 'ARRAY';

    if ($self->{_firing}) {
        if (!$self->{_flags}{once}) {
            $self->log("[fireing] once not flagged. register context and args to stack");
            push @{ $self->{_stack} }, [$context, $args];
        }
    } elsif (!($self->{_flags}{once} && ($self->{_memory} || 0) eq 1)) {
        $self->log("once not flagged or memory exists. fire");
        $self->{_fire}->($context, $args);
    }

    $self
}

sub fire {
    my $self = shift;
    $self->fire_with($self, \@_);
}

sub fired { !!shift->{_memory} }

1;
