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


do {
    diag "RAII and single registration test";
    my $cb = Sub::Deferred::Callbacks->new;
    is ref($cb), "Sub::Deferred::Callbacks";
    my $foo = 0;
    $cb->add(sub { ++$foo; });
    $cb->fire;
    is $foo, 1, '$fooの値は1';
};

do {
    diag "double registration test 1";
    my $cb = Sub::Deferred::Callbacks->new;
    is ref($cb), "Sub::Deferred::Callbacks";
    my $foo = 0;
    $cb->add(sub { ++$foo; });
    $cb->add(sub { ++$foo; });
    $cb->fire;
    is $foo, 2, '$fooの値は2';
};

do {
    diag "double registration test 2";
    my $cb = Sub::Deferred::Callbacks->new;
    is ref($cb), "Sub::Deferred::Callbacks";
    my $foo = 0;
    $cb->add([sub { ++$foo; }, sub { ++$foo; }]);
    $cb->fire;
    is $foo, 2, '$fooの値は2';
};

do {
    diag "remove method test";
    my $cb = Sub::Deferred::Callbacks->new;
    my $foo = 0;
    my $add = sub { ++$foo; };
    $cb->add($add);
    $cb->remove($add);
    $cb->fire;
    is $foo, 0, '$fooのインクリメントはされないので0';
};

do {
    diag "has method test";
    my $cb = Sub::Deferred::Callbacks->new;
    my $foo = 0;
    my $add = sub { ++$foo; };
    $cb->add($add);
    ok $cb->has($add), '$addの処理が登録されている';
    $cb->remove($add);
    ok !$cb->has($add), '$addの処理が削除されている';
};

do {
    diag "lock method test 1";
    my $cb = Sub::Deferred::Callbacks->new;
    $cb->lock;
    ok $cb->locked, 'ロックされている';
    ok $cb->disabled, "使用不能になっている";
};

do {
    diag "lock method test 2";
    my $cb = Sub::Deferred::Callbacks->new(memory => 1);
    $cb->add(sub {});
    $cb->fire;
    $cb->lock;
    ok $cb->locked, 'ロックされている';
    ok !$cb->disabled, "使用不能になっていない";
};

do {
    diag "lock method test 3";
    my $cb = Sub::Deferred::Callbacks->new;
    $cb->add(sub {});
    $cb->fire;
    $cb->lock;
    ok $cb->locked, 'ロックされている';
    ok $cb->disabled, "使用不能になっている";
};

do {
    diag "disable method test";
    my $cb = Sub::Deferred::Callbacks->new;
    $cb->disable;
    ok $cb->locked, 'ロックされている';
    ok $cb->disabled, '使用不能になっている';
};

do {
    diag "fired method test";
    my $cb = Sub::Deferred::Callbacks->new;
    ok !$cb->fired, 'まだ処理は発火していない';
    $cb->add(sub { 'noop' });
    ok !$cb->fired, '登録しただけなので、まだ処理は発火していない';
    $cb->fire;
    ok $cb->fired,'fireメソッドがコールされた';
};

do {
    diag "empty method test";
    my $cb = Sub::Deferred::Callbacks->new;
    my $foo = 0;
    $cb->add(sub { ++$foo; });
    $cb->empty;
    $cb->fire;

    is $foo, 0, '$fooの値は変わらない';
};

do {
    diag "stop_on_false test 1";
    my $cb = Sub::Deferred::Callbacks->new(stop_on_false => 1);
    my $foo = 0;
    my $add = sub { ++$foo; 0 };
    $cb->add($add);
    $cb->add($add);
    $cb->fire;

    is $foo, 1, "一度しか実行されない";

    ok !$cb->disabled, "onceでないのでdisabledにならない";

    $cb->add($add);
    $cb->fire;

    is $foo, 2, "登録すればもう一度実行できる";
};

do {
    diag "stop_on_false test 2";
    my $cb = Sub::Deferred::Callbacks->new(once => 1, stop_on_false => 1);
    my $foo = 0;
    my $add = sub { ++$foo; 0 };
    $cb->add($add);
    $cb->add($add);
    $cb->fire;

    is $foo, 1, "一度しか実行されない";

    ok $cb->disabled, "onceフラグがあるのでdisabledになってる";
};

do {
    diag "memory test";
    my $cb = Sub::Deferred::Callbacks->new(memory => 1);
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->add($add);
    $cb->fire;
    $cb->add($add);
    $cb->fire;
    is $foo, 2, '$fooの値は2';
};

do {
    diag "unique test";
    my $cb = Sub::Deferred::Callbacks->new(unique => 1);
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->add($add);
    $cb->add($add);
    $cb->fire;
    is $foo, 1, '$fooの値は1';
};

do {
    diag "once test";
    my $cb = Sub::Deferred::Callbacks->new(once => 1);
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->add($add);
    $cb->add($add);
    $cb->fire;
    $cb->add($add);
    $cb->fire;
    is $foo, 2, '$fooの値は2';
};

do {
    diag "firing add test 1";
    my $cb = Sub::Deferred::Callbacks->new;
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->add($add);
    $cb->add($add);
    $cb->{_firing} = 1;
    $cb->fire;
    $cb->add($add);
    $cb->fire;
    $cb->{_firing} = 0;
    $cb->fire;
    is $foo, 9, '$fooの値は9';
};

do {
    diag "firing add test 2";
    my $cb = Sub::Deferred::Callbacks->new(once => 1);
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->add($add);
    $cb->add($add);
    $cb->{_firing} = 1;
    $cb->fire;
    $cb->add($add);
    $cb->fire;
    $cb->{_firing} = 0;
    $cb->fire;
    is $foo, 3, '$fooの値は3';
};

do {
    diag "firing remove test 1";
    my $cb = Sub::Deferred::Callbacks->new;
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->add($add);
    $cb->add($add);
    $cb->{_firing} = 1;
    $cb->remove($add);
    $cb->{_firing} = 0;
    $cb->fire;
    is $foo, 0, '$fooの値は0';
};

do {
    diag "firing remove test 2";
    my $cb = Sub::Deferred::Callbacks->new;
    my $foo = 0;
    my $add = sub { ++$foo };
    $cb->{_firing} = 1;
    $cb->add($add);
    $cb->add($add);
    $cb->remove($add);
    $cb->{_firing} = 0;
    $cb->fire;
    is $foo, 0, '$fooの値は0';
};

done_testing;
