use inc::Module::Install;
name 'Sub-Deferred';
all_from 'lib/Sub/Deferred.pm';

# requires '';

tests 't/*.t';
#author_tests 'xt';

test_requires 'Test::More';
test_requires 'AnyEvent';
auto_set_repository;
auto_include;
WriteAll;
