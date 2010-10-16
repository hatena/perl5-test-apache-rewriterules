#!/usr/bin/perl
use strict;
use warnings;

print "Content-Type: text/plain; charset=us-ascii

$ENV{HTTP_HOST}
$ENV{REQUEST_URI}
$ENV{PATH_TRANSLATED}" . ($ENV{REQUEST_URI} =~ /\?/ ? '?'.$ENV{QUERY_STRING} : '');
