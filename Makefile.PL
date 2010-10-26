use inc::Module::Install;
name 'Test-Apache-RewriteRules';
all_from 'lib/Test/Apache/RewriteRules.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
