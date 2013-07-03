
######################################################################
# Blocks.pm
#
# Simple protocol:
# First byte of block == '0' => no blocks follow this block
# First byte of block != '0' => more blocks follow this block
# Second byte of block == message status code
#
######################################################################

## use constant BLOCKSIZE => 65536;
## use constant BLOCKSIZE => 32768;
## use constant BLOCKSIZE => 16384;
## use constant BLOCKSIZE => 8192;
## use constant BLOCKSIZE => 4096;
## use constant BLOCKSIZE => 2048;

use constant BLOCKSIZE => 4096;

## Message status codes

      ##
      ## Set by sender:
      ##
use constant S_REQUEST       => '0';
use constant S_OK            => '1';
use constant S_NO_DATA       => '2';
use constant S_BAD_REQUEST   => '3';
use constant S_RESPONSE_FAIL => '4';
      ##
      ## Set by sender:
      ##
use constant S_RECEIVE_FAIL  => '5';

use constant HDR_SZ => 7;
  ## First byte: is this block the last block
  ## Second byte: message status code
  ## Third thru seventh bytes: length of actual data in this block,
  ##    as a character string, with leading spaces

######################################################################
my $outgoing_message_status = S_OK;

sub GetStatus {
  return $outgoing_message_status;
}

sub SetStatus {
  $outgoing_message_status = shift;
}

######################################################################
sub SendBlocks {
  my ($file_handle, $dataref) = @_;
  my ($i, $buffer, $data_length, $num_blocks);

  my $len;

  $data_length = length($$dataref);

  ##
  ## data is empty
  ##
  if ($data_length < 1) {
    if (not defined send($file_handle, ('0' . GetStatus()) .
      sprintf("%5d", 0), "")) {
      return 0;
    } else {
      return 1;
    }
  }

  my $i = 0;
  while ($data_length > 0) {

    if ($data_length > (BLOCKSIZE - HDR_SZ)) {
      $len = BLOCKSIZE - HDR_SZ;
    } else {
      $len = $data_length;
    }
    $data_length = $data_length - $len;
    $buffer =
        ($data_length == 0 ? '0' : '1') .
        GetStatus() . sprintf("%5d", $len) .
        substr($$dataref, $i, $len);
    if (not defined send($file_handle, $buffer, "")) {
      return 0;
    }
    $i = $i + $len;
  }

  return 1;
}

######################################################################
sub RecvBlocks {
  my ($file_handle, $dataref) = @_;
  my $buffer;

  while (1) {

    my $header = "";
    my $got = 0;
    while (length($header) < HDR_SZ) {
      my $header1;
      if (not defined recv($file_handle, $header1, HDR_SZ - $got, "")) {
        return S_RECEIVE_FAIL;
      }
      $got = $got + length($header1);
      $header = $header . $header1;
    }
    my $data_length = int(substr($header, 2, 5));
    while ($data_length > 0) {
      if (not defined recv($file_handle, $buffer, $data_length, "")) {
        return S_RECEIVE_FAIL;
      }
      $data_length = $data_length - length($buffer);
      $$dataref = $$dataref . $buffer;
    }
    if (substr($header, 0, 1) == '0') {
      ##
      ## Take message status from last block
      ##
      return substr($header, 1, 1);
    }
  }

}

######################################################################
1;

