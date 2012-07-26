use strict;
use warnings;
use utf8;

use Test::More;
use AnyEvent;

use Sub::Deferred;
$Sub::Deferred::DEBUG++;

{
    # utf8 hack.
    binmode Test::More->builder->$_, ":utf8" for qw/output failure_output todo_output/;
    no warnings 'redefine';
    my $code = \&Test::Builder::child;
    *Test::Builder::child = sub {
        my $builder = $code->(@_);
        binmode $builder->output,         ":utf8";
        binmode $builder->failure_output, ":utf8";
        binmode $builder->todo_output,    ":utf8";
        return $builder;
    };
}


do {
    diag "RAII test";
    my $def = Sub::Deferred->new;
    is ref($def), "Sub::Deferred::Promise";
};

do {
    diag "resolve test";
    my $def = Sub::Deferred->new;
    $def->resolve;
    is $def->state, 'resolved', "state change: resolved";
    ok $def->is_resolved, "is_resolved: true";
    ok !$def->is_rejected, "is_rejected: false";
};

do {
    diag "resolve_with test";
    my $def  = Sub::Deferred->new;
    my $def2 = Sub::Deferred->new;
    $def->resolve_with($def2);
    is $def2->state, 'resolved', "state change: resolved";
};

do {
    diag "reject test";
    my $def = Sub::Deferred->new;
    $def->reject;
    is $def->state, 'rejected', "state change: rejected";
    ok !$def->is_resolved, "is_resolved: false";
    ok $def->is_rejected, "is_rejected: true";
};

do {
    diag "reject_with test";
    my $def  = Sub::Deferred->new;
    my $def2 = Sub::Deferred->new;
    $def->reject_with($def2);
    is $def2->state, 'rejected', "state change: rejected";
};

do {
    diag "constractor test";
    Sub::Deferred->new({});
    Sub::Deferred->new(sub {
        ok 1, "constractor called";
    });
};

do {
    diag "Sub::Deferred->when test 1";
    local $Sub::Deferred::DEBUG = 0;
    my $cv = AE::cv;
    my $def1 = Sub::Deferred->new;
    my $def2 = Sub::Deferred->new;
    my $def3 = Sub::Deferred->new;
    my $when = Sub::Deferred->when($def1, $def2, $def3);
    my $foo = 2;
    my $t1 = AE::timer 1, 0, sub {
        $foo *= 2;
        diag "[deferred call] 1";
        $def1->resolve;
    };
    my $t2 = AE::timer 2, 0, sub {
        $foo *= 2;
        diag "[deferred call] 2";
        $def2->resolve;
    };
    my $t3 = AE::timer 1, 0, sub {
        $foo *= 2;
        diag "[deferred call] 3";
        $def3->resolve;
    };
    $when->done(sub {
        $foo *= 3;
        diag "[deferred call] done";
        $cv->send($foo);
     });

    is $cv->recv, 48, "foo == 48";
};

do {
    diag "Sub::Deferred->when test 2";
    local $Sub::Deferred::DEBUG = 0;
    my $cv = AE::cv;
    my $def1 = Sub::Deferred->new;
    my $def2 = Sub::Deferred->new;
    my $when = Sub::Deferred->when($def1, $def2);
    my $foo = 2;
    my $t1 = AE::timer 2, 0, sub {
        $foo *= 2;
        diag "[deferred call] 1";
        $def1->resolve;
    };
    my $t2 = AE::timer 1, 0, sub {
        $foo *= 2;
        diag "[deferred call] 2";
        $def2->resolve;
    };
    $when->done(sub {
        $foo *= 3;
        diag "[deferred call] done";
        $cv->send($foo);
     });

    is $cv->recv, 24, "foo == 24";
};

do {
    diag "Sub::Deferred->when test 3";
    local $Sub::Deferred::DEBUG = 0;
    my $cv = AE::cv;
    my $def1 = Sub::Deferred->new;
    my $when = Sub::Deferred->when($def1, { foo => 5 });
    my $foo = 2;
    my $t1 = AE::timer 2, 0, sub {
        $foo *= 2;
        diag "[deferred call] 1";
        $def1->resolve;
    };
    $when->done(sub {
        $foo *= 3;
        diag "[deferred call] done";
        $cv->send($foo);
     });

    is $cv->recv, 12, "foo == 12";
};

done_testing;
