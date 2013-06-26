#!/usr/local/bin/perl

use strict;
use LWP::Simple;

my @accs;

## open(MAIL, "|/usr/lib/sendmail -t");
open(MAIL, "|/usr/lib/sendmail -t");
## print MAIL "To: hised\@mail.nih.gov\n";
print MAIL "To: wuko\@mail.nih.gov\n";
print MAIL "To: kotien\@verizon.net\n";
print MAIL "From: wuko\@mail.nih.gov\n";
print MAIL "Subject: build\n";
print MAIL "CGAP build is successful!\n";
close (MAIL);

