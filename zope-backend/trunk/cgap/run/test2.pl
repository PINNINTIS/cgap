#!/usr/local/bin/perl 
use String::Clean::XSS;
use CGI qw(:standard);

$user_data = "^@&@<>'`JGGERHJG"; 
#$user_data = $_; 
my $speh = clean_XSS($user_data);
my $speh_escape = escapeHTML($speh);

print " cleaned ".$speh."\n";
print " escaped  ".$speh_escape."\n";
print " as is  ".$user_data."\n"; exit(0); 
