#!/usr/local/bin/python

import sys
import re
import string
import tempfile
import commands
from CommonUtilities import *

######################################################################
def TestClient (host, port, file):

  resp = MakeRequest(host, port, \
      "Get(" + \
          "'" + file + "')" )
  print resp

######################################################################

host = sys.argv[1]
port = sys.argv[2]
file = sys.argv[3]
TestClient(host, int(port), file)

