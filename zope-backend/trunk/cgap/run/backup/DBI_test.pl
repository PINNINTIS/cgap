#!/usr/local/bin/perl

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
  push @INC, join("/", "/app/oracle/product/10gClient");
  push @INC, join("/", "/app/oracle/product/10gClient/lib");
  push @INC, join("/", ".");
}

## use lib "/usr/lib64/perl5/site_perl/5.8.5"; 
use lib "/app/oracle/product/10gClient/lib"; 

use CGAPConfig;

print "Content-type: text/plain\n\n";

print "7777: I am here<br>\n";

my @envs;

for my $env (keys %ENV) {
  my $cmd = "export $env";
  system($cmd);
  print STDERR "$env: $ENV{$env}\n";
  push @envs, "$env: $ENV{$env}";
}

print join("<br>", @envs) . "<br>";
## return join("<br>", @envs) . "<br>";

use DBI;
my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
print "8888: I am here<br>\n";
if (not $db or $db->err()) {
  print "Cannot connect to " .$DB_USER . "\/" .$DB_PASS . "@" . $DB_INSTANCE . "<br>\n";
}
print "9999: I am here<br>\n";
