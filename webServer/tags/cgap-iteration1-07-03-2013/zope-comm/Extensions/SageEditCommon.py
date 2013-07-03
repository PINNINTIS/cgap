#! /usr/local/bin/python

from socket import *

## BLOCKSIZE = 65536
## BLOCKSIZE = 32768
## BLOCKSIZE = 16384
## BLOCKSIZE = 8192
## BLOCKSIZE = 4096
## BLOCKSIZE = 2049

BLOCKSIZE = 1024

## Message status codes

     ##
     ## Set by sender:
     ##
S_REQUEST       = '0'   ## The transmission is a request
S_OK            = '1'   ## Request was well-formed, and server
                        ## found data matching the query  
S_NO_DATA       = '2'   ## Request was well-formed, but server
                        ## found no data matching the query
S_BAD_REQUEST   = '3'   ## The request was not well-formed
S_RESPONSE_FAIL = '4'   ## Server failed
     ##
     ## Set by receiver:
     ##
S_RECEIVE_FAIL  = '5'   ## Incoming transmission not received properly

HDR_SZ = 2        ## First byte: is this the last block
                  ## Second byte: message status code

global_response_status = S_OK

######################################################################
def GlobalResponseStatus ():
  return global_response_status

######################################################################
def SendBlocks (handle, data):
  import string
  data_length = len(data)
  num_blocks = data_length / (BLOCKSIZE - HDR_SZ)
  if (data_length % (BLOCKSIZE - HDR_SZ) > 0):
    num_blocks = num_blocks + 1
  written = 0
  while (num_blocks > 0):
    if num_blocks > 1:
      to_write = BLOCKSIZE - HDR_SZ
      flag = '1'
    else:
      to_write = data_length - written
      flag = '0'
    buffer = flag + S_REQUEST + data[written:(written+to_write)]
    written = written + to_write
    num_blocks = num_blocks - 1
    handle.send(buffer)

######################################################################
def RecvBlocks (handle):
  import string
  lines = []
  while (1):
    buf = handle.recv(BLOCKSIZE)
    lines.append(buf[2:])
    if buf[0] == '0':
      break
  return (buf[1], string.join(lines, ""))

######################################################################
def MakeRequest (host, port, req):

  global global_response_status

  try:
    s = socket(AF_INET, SOCK_STREAM)
    s.connect((host, port))
    SendBlocks(s, req)
    (global_response_status, s1) = RecvBlocks(s)
    s.close()
  except:
    global_response_status = S_RESPONSE_FAIL
    s1 = "Database temporarily unavailable"
  return s1

######################################################################
def GetRequestParam (request, s):
  import re
  import string
  if request.has_key(s):
    p = request[s]
    if type(p) == type(''):
      q = p
    else:
      q = string.join(p, ",")
  else:
    q = ''
  return q

######################################################################
def BaseHref (parents):
  j = ""
  for i in parents[:-2]:
    j = str(i.id) + "/" + j
  return j

######################################################################
def BackEnd (host, port, path, base, cmd, \
    requestparamnames, otherparamnames, request, other):

  import re
  import string
  import tempfile
  import urllib
  import commands  

  p = []

  if host == "" and path != "":
    usesocket = 0
    if re.compile("^http:", re.I).match(path):
      usehttp = 1
      useexec = 0
    else:
      usehttp = 0 
      useexec = 1
##    tmpfn = tempfile.mktemp()
##    tmpf = open(tmpfn, "w")
  elif path == "" and host != "":
    usesocket = 1
    useexec   = 0
    usehttp   = 0
  else:
    return "Error: host and path are both specified"

  if usehttp:
    other['BASE'] = base
  elif usesocket:
    p.append("'" + base + "'")
  elif useexec:
    p.append("'" + base + "'")

  for i in re.split(",", requestparamnames):
    param = str(GetRequestParam(request, i))
    if usesocket:
      p.append("'" + param + "'")
    elif useexec or usehttp:
      if usehttp:                 ## move relevant request params to other
        if other.has_key(i):
          if type(other[i]) == type(''):
            if other[i] == "" and param != "":
              other[i] = param
            else:
              pass
          else:
            other[i].append(param)
        else:
          other[i] = param
      else:
        p.append("'" + param + "'")
##      tmpf.write(param + "\n")

  for i in re.split(",", otherparamnames):
    param = str(GetRequestParam(request, i))
    if usesocket:
      p.append("'" + param + "'")
    elif useexec:
      if usehttp:
        pass
      else:
        p.append("'" + param + "'")
##      tmpf.write(param + "\n")

  if useexec:
    (status,response) = commands.getstatusoutput \
        (path + "/" + cmd + " "  + string.join(p, " "))
##    tmpf.close()

  elif usehttp:
    httpcmd = path + "/" + cmd
    f = urllib.urlopen(httpcmd, urllib.urlencode(other))
    response = f.read()

  elif usesocket:
    response = MakeRequest(host, port, cmd + "(" + string.join(p, ", ") + ")" )

  return response

######################################################################
def DisplayEditPage (request):
  import urllib

  user_id = GetRequestParam(request, "REMOTE_ADDR")
  approved_id = GetRequestParam(request, "approved_id")
  approved_name = GetRequestParam(request, "approved_name")
  pending_id = GetRequestParam(request, "pending_id")
  pending_name = GetRequestParam(request, "pending_name")

  value = BackEnd('',0,'http://lpgprot101.nci.nih.gov/sagecgi/SageEdit','','DisplayEditPage.pl','REMOTE_ADDR,approved_id,approved_name,pending_id,pending_name','',request,{})
  
  urllib.urlretrieve('http://lpgprot101.nci.nih.gov:5080/CGAP','cgap_example.html')
  frame = 'NO';
  BackEnd('',0,'http://lpgprot101.nci.nih.gov:5080/CGAP','','DisplayEditPage.jsp','frame','',request,{})
