# RHEL 8 Secure Kickstart - DISA STIG Baseline
# Wipe all existing partitions on /dev/sda and initialize disk label (GPT by default in RHEL8)
text
clearpart --all --initlabel --drives=sda
zerombr

# Bootloader configuration: install GRUB2 to MBR (for BIOS) 
#bootloader --location=mbr --timeout=5 --append="audit=1 crashkernel=auto"


# Partitioning scheme (LVM on 1TB disk) following DISA STIG guidance:contentReference[oaicite:9]{index=9}:
# - Separate /boot, /home, /tmp, /var, /var/tmp, /var/log, /var/log/audit (each on LVs):contentReference[oaicite:10]{index=10}.
# - Use XFS for all Linux filesystem partitions (RHEL default).
# - Mount options "nodev", "noexec", "nosuid" applied where appropriate for security.
# - Leave some free space in Volume Group for future growth or additional volumes.
part /boot --fstype="xfs" --size=1024   --ondisk=sda   # /boot partition (1 GB)
part /boot/efi --fstype="efi" --size=600 --ondisk=sda  # UEFI system partition (if BIOS, this is ignored)
part pv.01 --fstype="lvmpv" --grow --size=1 --ondisk=sda --encrypted --luks-version=luks2 --passphrase=changeme

volgroup vg_rhel8 pv.01  # Volume Group spanning the PV

#Logical volumes for each mount point:

logvol /              --fstype="xfs" --size=10240  --name=root    --vgname=vg_rhel8
logvol /home          --fstype="xfs" --size=10240  --name=home    --vgname=vg_rhel8 --fsoptions="nodev"
logvol /tmp           --fstype="xfs" --size=4096   --name=tmp     --vgname=vg_rhel8 --fsoptions="nodev,noexec,nosuid"
logvol /var           --fstype="xfs" --size=30720  --name=var     --vgname=vg_rhel8 --fsoptions="nodev"
logvol /var/tmp       --fstype="xfs" --size=2048   --name=var_tmp --vgname=vg_rhel8 --fsoptions="nodev,noexec,nosuid"
logvol /var/log       --fstype="xfs" --size=10240  --name=var_log --vgname=vg_rhel8 --fsoptions="nodev,noexec,nosuid"
logvol /var/log/audit --fstype="xfs" --size=5120   --name=audit   --vgname=vg_rhel8 --fsoptions="nodev,noexec,nosuid"
logvol swap           --fstype="swap" --size=4096  --name=swap    --vgname=vg_rhel8





#Network configuration: static IP for air-gapped setup
network --nameserver=10.18.10.150,1.1.1.1


# System settings
keyboard --xlayouts='us'
lang en_US.UTF-8
eula --agreed
timezone America/Los_Angeles --isUtc --nontp
authselect --useshadow --passalgo=sha512  # Use shadow passwords, SHA-512 hashing (secure defaults)
selinux --enforcing               # Enforce SELinux (STIG requires SELinux on)
firewall --enabled --service=ssh  # Enable firewall, allow SSH (other ports closed by default)
firstboot --disable               # Skip interactive first-boot configuration

# root password: STIG requires a complex password. It's recommended to set a strong password or lock root.
rootpw --iscrypted $6$zFtzsMDwpgfeff0g$2bq2BpmbyNDT4wmQTQozKVC09C1pZuU52fvIO1sgFCQ8Oi.GCz5s2TPb/Pgpl4ZURH7zA/rM82Ck8to3iL3Pu1


%addon com_redhat_kdump --disable --reserve-mb='auto'
%end

#%addon org_fedora_oscap
#    content-type = scap-security-guide
#    datastream-id = scap_org.open-scap_datastream_from_xccdf_ssg-rhel8-xccdf.xml
#    xccdf-id = scap_org.open-scap_cref_ssg-rhel8-xccdf.xml
#    profile = xccdf_org.ssgproject.content_profile_stig_gui
#%end
#

%packages
@^minimal-environment
autofs
nfs-utils
chrony
libselinux
openssh-server
rsyslog
rsyslog-gnutls
firewalld
aide
audit
fapolicyd
policycoreutils
postfix
rng-tools
mailx
scap-security-guide
tmux
usbguard
openscap
openscap-scanner
opensc
realmd
sssd
oddjob
oddjob-mkhomedir
adcli
samba-common
samba-common-tools
krb5-workstation
bash-completion
# Tools for Ansible and STIG roles (optional)
@rpm-development-tools
@security-tools

#needed for me to run ansible lockdown playbook
#ansible-core
python3
git
libselinux-python*
policycoreutils*
python3-pexpect
glibc-langpack-en


# REMOVE insecure/unnecessary services
-abrt
-abrt-addon-ccpp
-abrt-addon-kerneloops
-abrt-cli
-abrt-plugin-sosreport
-iprutils
-krb5-server
-libreport-plugin-logger
-python3-abrt-addon
-rsh-server
-sendmail
-telnet-server
-tftp-server
-tuned
%end




%post --nochroot
mkdir /mnt/files
mount -o nolock 10.18.10.100:/EXPORT/FILES /mnt/files
cp -r /mnt/files /mnt/sysimage/root/files
umount /mnt/files
%end



%post
log='/root/post-install.log'
echo "CP autofs configs and yum config and rpm gpg key" >> "$log"
cd /root/files
cp auto.share1 /etc/auto.share1
cp auto.master /etc/auto.master
rpm --import /home/repos/rhel8/RPM-GPG-KEY-redhat-release
cp redhat.repo /etc/yum.repos.d/redhat.repo
cp epel.repo	/etc/yum.repos.d/epel.repo
%end


%post
useradd -s /bin/bash sasroot
usermod -aG wheel sasroot
echo "sasroot:1qaz2wsx!QAZ@WSX" | chpasswd
chage sasroot -d $(date +%Y-%m-%y)
chage -m 1 sasroot
chage -M 60 sasroot
#V-230325 - All RHEL 8 local initialization files must have mode 0740 or less permissive.
chmod -R 740 /home/sasroot

chage root -d $(date +%Y-%m-%y)
chage -m 1 root
chage -M 60 root

cp /root/files/stig_sudo /etc/sudoers.d/stig_sudo
echo "%linux-admins@jupiter.com ALL=(ALL) ALL" > /etc/sudoers.d/linux-admins
chmod 440 /etc/sudoers.d/linux-admins

#V-230381 - RHEL 8 must display the date and time of the last successful account logon upon logon.
#echo "session required pam_lastlog.so showfailed" >> /etc/pam.d/postlogin
#%end 

%post
systemctl enable autofs
systemctl enable firewalld
%end



