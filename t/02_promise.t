use strict;
use warnings;
use utf8;

use Test::More;

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

sub make_promise {
    my $pr_o = {
	resolve => [],
	reject  => [],
	notify  => []
    };
    my $pr;
    $pr = Sub::Deferred::Promise->new({
        done => sub {
            for my $fn (@_) {
                push @{ $pr_o->{resolve} }, $fn;
            }
        },
        fail => sub {
            for my $fn (@_) {
                push @{ $pr_o->{reject} }, $fn;
            }
        },
        progress => sub {
            for my $fn (@_) {
                push @{ $pr_o->{notify} }, $fn;
            }
        },
        state => 'pending',
        is_resolved => sub { 1 },
        is_rejected => sub { 0 },
        key_fire => sub {
	    my $key = shift;
	    $_->($pr, @_) for @{ $pr_o->{$key} };
	},
        key_fire_with => sub {}
    });
}

do {
    diag "RAII test";
    my $pr = make_promise();
    is ref($pr), "Sub::Deferred::Promise";
};

do {
    diag "call test";
    my $pr = make_promise();
    is $pr->done, $pr, "done: self returned";
    is $pr->fail, $pr, "fail: self returned";
    is $pr->progress, $pr, "progress: self returned";
    is $pr->state, "pending", "";
    is $pr->is_resolved, 1, "";
    is $pr->is_rejected, 0, "";
    is $pr->resolve, $pr, "resolve: self returned";
    is $pr->reject, $pr, "reject: self returned";
    is $pr->notify, $pr, "notify: self returned";
    is $pr->resolve_with, $pr, "resolve_with: self returned";
    is $pr->reject_with, $pr, "reject_with: self returned";
    is $pr->notify_with, $pr, "notify_with: self returned";
    is $pr->then(sub {}, sub {}, sub {}), $pr, "then: self returned 1";
    is $pr->then, $pr, "then: self returned 2";
    is $pr->then([sub {}], [sub {}], [sub {}]), $pr, "then: self returned 1";
    isnt $pr->pipe(sub {}, sub {}, sub {}), $pr, "new Sub::Deferred::Promise instance returned 1";
    isnt $pr->pipe, $pr, "new Sub::Deferred::Promise instance returned 2";
};

do {
    diag "promise test";
    my $pr = make_promise();
    my $pr2 = $pr->promise;
    isnt $pr, $pr2, "promise returns different instance";
    my $pr3 = $pr->promise({});
    isnt $pr, $pr3, "promise returns different instance";

    my $stderr;
    local $SIG{__WARN__} = sub { $stderr = shift };

    for my $w (qw/resolve reject notify/) {
	$pr2->$w;
	like $stderr, qr/invalid call: $w/, "can't call ${w}";
    }
    for my $w (qw/resolve_with reject_with notify_with/) {
	(my $w2 = $w) =~ s/_with//;
	$pr2->$w;
	like $stderr, qr/invalid call: $w2/, "can't call ${w}";
    }

};

do {
    diag "always test";

    my $pr = make_promise();

    my $foo = 0;

    my $always = sub { ++$foo };
    $pr->always($always);
    $pr->resolve;
    is $foo, 1, "resolve: foo == 1";

    my $pr2 = make_promise();

    $pr2->always($always);
    $pr2->reject;
    is $foo, 2, "resolve: foo == 2";
};

do {
    diag "pipe test";

    my $pr = make_promise();
    my $foo = 0;
    $pr->pipe(sub { ++$foo })->pipe(sub { ++$foo });
    $pr->resolve;
    is $foo, 2, "foo == 2";
};

done_testing;
