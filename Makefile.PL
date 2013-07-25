use inc::Module::Install;
name 'Nagios-Quicky';
all_from 'lib/Nagios/Quicky.pm';

requires 'Parallel::ForkManager';
requires 'Path::Class';
requires 'MongoDB';
requires 'Class::Accessor::Lite';
requires 'Mojolicious::Lite';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
