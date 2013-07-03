######################################################################
# ServerSupport.pm
######################################################################

use Socket;
use Blocks;
#use CGAPConfig;

use Exporter ();
@ISA = qw(Exporter);
@EXPORT = qw (
  SetSafe
  SetForkable
  SetMaxChildren
  PeerServerQuery
  StartServer
  GetBuildIDs
  ResetServer
  KillServer
  SetProgramName
);


my %safe_requests;
my %forkable_requests;
my %async_requests;
my %safe_ips;
my $waitedpid;

my $max_children = 3;          ## max number of simultaneous spawned
                               ## subprocesses
my $num_current_children = 0;
my $query_timeout = 500;       ## max length (in seconds) for a request
                               ## to run before exiting/resetting server

my $in_child;

for (split(",",SAFE_IPS)) {
  $safe_ips{$_} = 1;
}

######################################################################
sub SetSafe {
  for my $cmd (@_) {
    $safe_requests{$cmd} = 1;
  }
}

######################################################################
sub SetForkable {
  for my $cmd (@_) {
    $forkable_requests{$cmd} = 1;
  }
}

######################################################################
sub SetAsync {
  my ($cmd, $async_cmd) = @_;
  $async_requests{$cmd} = $async_cmd;
}

######################################################################
sub SetMaxChildren {
  $max_children = shift;
}

######################################################################
sub SplitRequest {
  my $request = shift;
  my @r = split /\(/, $request;
  my $verb = shift @r;
  $verb =~ s/ //g;
  return ($verb, "(" . join("(", @r));
}

######################################################################
sub GetCmd {
  my $request = shift;
  split /\(/, $request;
  my $verb = $_[0];
  $verb =~ s/ //g;
  return $verb;
}

######################################################################
sub IsAsync {
  my $request = shift;
  my $verb = GetCmd($request);
  if (defined $async_requests{$verb}) {
    return 1;
  } else {
    return 0;
  }
}

######################################################################
sub IsSafe {
  my $request = shift;
  my $verb = GetCmd($request);
  if (defined $safe_requests{$verb}) {
    return 1;
  } else {
    return 0;
  }
}

######################################################################
sub IsForkable {
  my $request = shift;
  my $verb = GetCmd($request);
  if (defined $forkable_requests{$verb}) {
    return 1;
  } else {
    return 0;
  }
}

######################################################################
sub PeerServerQuery {

  my ($host, $port, $fh, $request) = @_;

  my $proto          = getprotobyname('tcp');
  my $iaddr          = gethostbyname($host);
  my $sin            = sockaddr_in($port, $iaddr);

  socket($fh, PF_INET, SOCK_STREAM, $proto) or
      return "PeerServerQuery:socket: $!";
  connect($fh, $sin) or
      return "PeerServerQuery:connect: $!";

  SetStatus(S_REQUEST);
  SendBlocks($fh, \$request);
  ## reset outgoing status
  SetStatus(S_OK);

  my $line;
  RecvBlocks($fh, \$line);

  return $line;
}

######################################################################
sub GetBuildIDs {
  my ($builds) = @_;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    exit();
  }

  my $sql = "select organism, build_id from $CGAP_SCHEMA.build_id";
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "prepare call failed\n";
    $db->disconnect();
    exit();
  } else {
    if ($stm->execute()) {
      while (($organism, $build_id) = $stm->fetchrow_array()) {
        if ((not defined $$builds{$organism}) or
            ($build_id > $$builds{$organism})) {
          $$builds{$organism} = $build_id;
        }
      }
    } else {
      print STDERR "execute failed\n";
      $db->disconnect();
      exit();
    }
  }
  $db->disconnect();

}

######################################################################
my $PROGRAM_NAME;
######################################################################
sub SetProgramName {
  $PROGRAM_NAME = shift;
}

my $client;

######################################################################
sub ResetServer {
  if ($PROGRAM_NAME) {
    close $client;
    close Server;
    exec $PROGRAM_NAME;
  }
}

######################################################################
sub KillServer {
  if ($PROGRAM_NAME) {
    close $client;
    close Server;
    exit;
  }
}

######################################################################
sub REAPER {
  $waitedpid = wait;
  if ($waitedpid > 0) {
    $num_current_children--;
  }
}

######################################################################
sub CatchAlarm {
  ## The timer popped
  SetStatus(S_RESPONSE_FAIL);
  my $request = "Server timed out\n";
  SendBlocks($client, \$request);
  close $client;
  if ($in_child) {
    exit();
  } else {
    ResetServer();
  }
}


######################################################################
sub StartServer {

  my ($this_port, $this_name) = @_;

  my $proto          = getprotobyname('tcp');
  my $paddr;
  my $request;
  my $response;

  my $pid;

  socket(Server, PF_INET, SOCK_STREAM, $proto)    or die "socket: $!";
  setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsockopt: $!";
  bind(Server, sockaddr_in($this_port, INADDR_ANY))     or die "bind: $!";
  listen(Server, SOMAXCONN);

  print "$this_name starting\n";

  $SIG{PIPE} = \&CatchSigpipe;
  $SIG{CHLD} = \&REAPER;
  $SIG{ALRM} = \&CatchAlarm;

  $client = new FileHandle;

  ## This method of forking taken from Programming Perl, 2nd edition, p.352.
  ## Requires the check on waitedpid, otherwise the accept appears to 
  ## fail (because of the jump to REAPER).
  ## But it does not appear that it is necessary for REAPER to reinstall
  ## the handler each time it is called.
  ## Have the child close the socket; otherwise (if parent closes
  ## socket prematurely) the other end gives up.
  LOOP: for ($waitedpid = 0 ;
      $paddr = accept($client, Server) || $waitedpid; $waitedpid = 0) {
    next if $waitedpid;  ## i.e., just harvested child
    ($pn,$ip) = unpack_sockaddr_in ($paddr);
    my @ip = unpack(C4,$ip);
#    if (not defined $safe_ips{join(".",@ip)}) {
#      close $client;
#      next;
#    }
    undef $request;
    RecvBlocks($client, \$request);
    if (IsSafe($request)) {
      if (IsForkable($request) and ($num_current_children < $max_children)) {
        FORK: {
          if ($pid = fork) {
            ## This is the parent; child pid in $pid
            $num_current_children++;
            next LOOP;
          } elsif (defined $pid) {        ## In child
            $in_child = 1;
            alarm $query_timeout;         ## Set timer
            $response = eval $request;
            ## catch exception so the socket can be closed.
            if ($@) {
              alarm 0;
              SetStatus(S_RESPONSE_FAIL);
              $response = "Server failed\n";
              SendBlocks($client, \$response);
              close $client;
              exit(0);        
            }
            alarm 0;                      ## Cancel timer
            SendBlocks($client, \$response);
            exit(0);      
          } elsif ($! =~ /No more process/) {
            sleep 5;
            redo FORK;
          } else {
            SetStatus(S_RESPONSE_FAIL);
            $response = "Server failed\n";
            print STDERR "Can't fork: $!\n";
          }
        }
      } elsif (IsForkable($request) and
          ($num_current_children >= $max_children)) {
          SetStatus(S_RESPONSE_FAIL);
          $response = "Database busy, try again in a few minutes\n";
      } else {                       ## Not forkable; in "parent"
        alarm $query_timeout;        ## Set timer
        $response = eval $request;
        if ($@) {
          SetStatus(S_RESPONSE_FAIL);
          $response = "Server failed\n";
        }
        alarm 0;                     ## Cancel timer
      }
    } else {
      $response = "Command not supported";
      SetStatus(S_BAD_REQUEST);
    }

    SendBlocks($client, \$response);
    close $client;

    if (GetStatus == S_OK && IsAsync($request)) {
      alarm $query_timeout;        ## Set timer
      StartAsync($request);
      alarm 0;
    }

    ## reset outgoing status
    SetStatus(S_OK);
  }

}

######################################################################
sub StartAsync {
  my ($request) = @_;

  my ($verb, $rest) = SplitRequest($request);
  my $request1 = $async_requests{$verb} . $rest;
  eval $request1;
}

######################################################################
sub CatchSigpipe {
}

1;

