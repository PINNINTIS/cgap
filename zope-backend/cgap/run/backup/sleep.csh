#!/bin/csh
set ROOT="http://cbvapp-d1016.nci.nih.gov:8080/SleepTest"
rm -f sleeptest.txt
foreach id ( 1 2 3 4 5 6 7 )
  wget -O - "$ROOT/SleepTest?id=$id&seconds=40&bytes=120" >> sleeptest.txt 
end

