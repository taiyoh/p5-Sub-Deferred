#!perl

use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Perl6::Say;

use Sub::Deferred;
use AnyEvent;

my $cv = AE::cv;
my @defs = map { Sub::Deferred->new } 1 .. 3;
my $when = Sub::Deferred->when(@defs);
my $foo = 2;
my @timers = map {
    my $def = $_;
    my $sec = int(rand 5) + 1;
    AE::timer $sec, 0, sub {
        say "$sec sec after";
        $foo *= 2;
        $def->resolve;
    };
} @defs;
$when->done(sub {
    $foo *= 3;
    $cv->send($foo);
});

say "result: ". $cv->recv; # => 48
