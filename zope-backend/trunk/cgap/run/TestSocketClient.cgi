#!/usr/local/bin/python

import sys
import re
import string
import tempfile
import commands
from CommonUtilities import *

######################################################################
def TestClient (host, port, file):

  print "Get(" + \
         "''," + \
         "'" + file + "')"
  resp = MakeRequest(host, port, \
      "Get(" + \
         "''," + \
         "'" + file + "')" )
  print resp

######################################################################

host = 'cbiovdev5047.nci.nih.gov'
port = 8009
file = '/tmp/caCHE/mc.434'
TestClient(host, int(port), file)

