#!/bin/sh
sudo sh /opt/nbfc/Linux/bin/Release/nbfcservice.sh start
mono /opt/nbfc/Linux/bin/Release/nbfc.exe config --apply default

# Check status of NBFC when manually running script
mono /opt/nbfc/Linux/bin/Release/nbfc.exe status -a
