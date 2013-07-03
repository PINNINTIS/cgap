#! /usr/bin/python

## BLOCKSIZE = 65536
## BLOCKSIZE = 32768
## BLOCKSIZE = 16384
## BLOCKSIZE = 8192
## BLOCKSIZE = 4096
## BLOCKSIZE = 2049
## BLOCKSIZE = 1024

BLOCKSIZE = 4096

HDR_SZ = 7
  ## First byte: is this block the last block
  ## Second byte: message status code
  ## Third thru seventh bytes: length of actual data in this block,
  ##    as a character string, with leading spaces

######################################################################
def SendBlocks (handle, status, data):
  import string

  data_length = len(data)
  written = 0
  while (data_length > 0):
    if (data_length > (BLOCKSIZE - HDR_SZ)):
      length = BLOCKSIZE - HDR_SZ
    else:
      length = data_length
    data_length = data_length - length
    if (data_length > 0):
      flag = 1
    else:
      flag = 0
    length_spec = "%5d" % length
    buffer = str(flag) + status + length_spec + \
        data[written:(written+length)]
    if (handle.send(buffer) != length + HDR_SZ):
      handle.close
      raise socket.error
    written = written + length

######################################################################
def RecvBlocks (handle):
  import string
  lines = []
  while (1):
    got = 0
    header1 = ''
    header  = ''
    while (got < HDR_SZ):
      header1 = handle.recv(HDR_SZ - got)
      got = got + len(header1)
      header = header + header1
    data_length = int(header[2:7])
    while (data_length > 0):
      buf = handle.recv(data_length)
      data_length = data_length - len(buf)
      lines.append(buf)
    if header[0] == '0':
      break
  return (header[1], string.join(lines, ""))

