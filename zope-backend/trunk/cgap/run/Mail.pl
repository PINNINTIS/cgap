#!/usr/local/bin/perl

use strict;
## use LWP::Simple;

print "Content-type: text/plain\n\n";

print "<center><br>Mail test</br></center>";

open(MAIL, "|/usr/lib/sendmail -t");
print MAIL "To: wuko\@mail.nih.gov\n";
## print MAIL "To: nwokehc\@mail.nih.gov\n";
print MAIL "From: ncicb\@pop.nci.nih.gov\n";
print MAIL "Subject: your stage mail test is completed\n";
print MAIL "Your stage mail test is completed\n";
close (MAIL);

