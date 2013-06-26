######################################################################
# Scan_Server.pm
######################################################################

use Exporter ();
@ISA = qw(Exporter);
@EXPORT = qw (
  Scan
);

######################################################################
sub Scan {
  for my $input (@_) {
    my $test = exam($input);
    if( $test =~ /Error in input/ ) {
      return $test; 
    }
  }
  return "";
}

######################################################################
sub exam {
  my ($inp) = @_; 
  my $input = $inp;
  ## if( ($input =~ /javascript/i) or ($input =~ /<script>.+<\/script>/i) ) {
  if( ($input =~ /javascript/i) or ($input =~ /\<script\>/i) or ($input =~ /\<\/script\>/i) or ($input =~ /vbscript/i) ) {
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    ## print "<br><b><center>Error in input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }
    
  if( ($input =~ /onMouseOver/i) or ($input =~ /onClick/i) ) {
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    print "<br><b><center>Error in input</b>!</center>";
    exit;
  }

  ## if( ($input =~ /alert\(.+\)/i) or ($input =~ /alert \(.+\)/i) ) {
  if( ($input =~ /alert/i) ) {
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    print "<br><b><center>Error in input</b>!</center>";
    exit;
  }

  if( $input =~ /background:/i ) {
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    ## print "<br><b><center>Error in input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }
    
  if( $input =~ /\<a.+\<\/a\>/i ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /=/ ) {
    my @tmp = split "=", $input;
    for (my $i=0; $i<@tmp; $i=$i+2) {
      $tmp[$i] =~ s/\s+$//;
      my @left = split /\s+/, $tmp[$i]; 
      $tmp[$i+1] =~ s/^\s+//;
      my @right = split /\s+/, $tmp[$i+1]; 
      my $left_index = @left;
      if( $left[$left_index-1] eq $right[0] ) {
        ## print "<br><b><center>Error in input</b>!</center>";
        ## print "<br><b><center>Error in input: $input</b>!</center>";
        return "<br><b><center>Error in input</b>!</center>";
      }
    }
  }

  if( $input =~ /\|\|/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\s+\|\s+/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }
  ## if( ($input =~ /\'\-\-/) or ($input =~ /\'\s+\-\-/) ) {
  if( $input =~ /\-\-/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\+\+/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\d+\+\d+/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\&\&/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\*\*.+\*\*/ ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\<IMG\s+SRC=/i ) {
    ## print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\'\;/ ) {
    print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    return "<br><b><center>Error in input</b>!</center>";
  }

  if( $input =~ /\\\'/ ) {
    print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>Error in input: $input</b>!</center>";
    exit;
  }
 
  ## if( $input =~ /\%\u/ ) {
  ##   print "<br><b><center>Error in input</b>!</center>";
  ##  ## print "<br><b><center>Error in input: $input</b>!</center>";
  ##   exit;
  ## }

  if( $input =~ /Watchfire\.+XSS\.+Test\.+Successful/ ) {
    print "<br><b><center>Error in input</b>!</center>";
  ##  ## print "<br><b><center>Error in input: $input</b>!</center>";
    exit; 
  }

  return "";

}

######################################################################

1;

