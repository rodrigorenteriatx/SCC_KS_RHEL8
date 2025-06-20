#!/bin/bash

#
#cd /root/files/SCAP/ansible
#./enforce.sh
#rhel8STIG_stigrule_230239_Manage: False
#rhel8STIG_stigrule_230502_Manage: False
#rhel8STIG_stigrule_230559_Manage: False


TARGET="/share1/SCANS/$(hostname)/$(date +%Y-%m-%d)"
CONTENT="U_RHEL_8_V2R1_STIG_SCAP_1-3_Benchmark.zip"
SEC_PROFILE="MAC-3_Sensitive"
mkdir -p "$TARGET"

rpm -ivh scc-5.10.1_rhel8_x86_64/scc*.rpm

cp $CONTENT /opt/scc

cd /opt/scc

./cscc --uninstallAll
./cscc --force -is "$CONTENT"
./cscc --setProfileAll "$SEC_PROFILE"

#Remove unecessary directories
./cscc --setOpt dirAllSessionsEnabled 0
./cscc --setOpt dirApplicationLogsEnabled 0
./cscc --setOpt dirContentTypeEnabled 0
./cscc --setOpt dirSessionEnabled 0
./cscc --setOpt dirSessionLogsEnabled 0
./cscc --setOpt dirSessionResultsEnabled 0
./cscc --setOpt dirStreamNameEnabled 0
./cscc --setOpt dirTargetNameEnabled 0
./cscc --setOpt dirXMLEnabled 0

#Set results directory for host (will run locally on each machine) 
#Should be set before every scap scan
./cscc --setOpt userResultsDirectoryValue 2
./cscc --setOpt userResultsDirectory "$TARGET"

#scan entire root filesystem
./cscc
echo $TARGET
#RUN INITIAL SCAN
