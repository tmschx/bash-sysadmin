#!/bin/bash
##
## /usr/local/script/slcheck.sh
## Perform system checks
##
## Created on 25 MEI 2013
## Version 1.0 dated 21 FEB 2015
##
## Arguments:
##	-v : verbose
##	-p : pauses between system functions
##	-f : specify system function
##	-h : displays usage
##

# Set variables and default values
set -u
F_VERBOSE=""			# Script verbose flag
F_PAUSE=""				# Script pause flag
FUNCTIONCHECK=""		# Main system function to check
PROCSTATE=""			# Process state to check
L_PROCSTATES="D R S T W X Z"	# List of valid process states
L_HDDs=""			# List of local hard disks
L_IFs=""			# List of network interfaces
L_SWUPDATE=""		# List of updatable software packages

# Define functions
function pause() {
	# Pauses if F_PAUSE flag has been set
	if [[ ${F_PAUSE} == TRUE && -z ${FUNCTIONCHECK} ]]; then
		read -p "Press [ENTER] to continue..."
	fi
}
function countelements() {
	# Return the number of elements in string
	echo $#
}

# Evaluate given options using getops; set variables accordingly
while getopts "f:vph" opt; do
   case "$opt" in
     f)
       FUNCTIONCHECK=${OPTARG}
       printf -- "System function specified: %s\n" "${FUNCTIONCHECK}"
       ;;
     v)
       F_VERBOSE=TRUE
       printf -- "Verbose mode: script will provide more detailed information. \n"
       ;;
     p)
       F_PAUSE=TRUE
       printf -- "Pause mode: script will wait after each main system function check.\n"
       ;;
     \? | h)
       printf -- "Usage: %s [-h] [-v] [-p]\n" "${0##*/}"
       printf -- "          [-f core | storage | network | security | web | database | pim | media]\n"
       printf -- "   -h   Help: show this help message and exit.\n"
       printf -- "   -v   Verbose mode: script will provide more detailed information.\n"
       printf -- "   -p   Pause mode: script will wait after each system function check.\n"
       printf -- "   -f   Specify system function to check.\n"
       exit 2
       ;;
     :)
       printf -- "Option -%s requires an argument. Exiting." "${OPTARG}"
       exit 1
       ;;
   esac
done

#### CORE 
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "core" ]]; then
	printf "==== CHECK 1. SYSTEM CORE \n"
	# Operating system information
	printf " == Operating system information "
	if [[ -x "/usr/bin/lsb_release" ]]; then
		printf " %s" "$(lsb_release -d | awk '{ print $2 }')"
		printf " %s" "$(lsb_release -r | awk '{ print $2 }')"
		printf " %s" "$(lsb_release -c | awk '{ print $2 }')"
	fi
	printf "\n"
	if [[ -x "/bin/uname" && "/usr/bin/w" && "/bin/hostname" ]]; then
		printf "   Hostname(s): %s\n" "$(hostname -A)"
		if [[ ${F_VERBOSE} == TRUE ]]; then
			uname -a | awk 'NF {print "     "$0}'
			w | awk 'NF {print "     "$0}'
		else
			w | head -n 1 | awk 'NF {print "     "$0}'
		fi
	else
		printf "  * ERROR: missing basic unix commands. Cannot obtain operating system information. \n"
	fi
	# Hardware
	printf " == Hardware information\n"
	if [ -x /usr/bin/sensors ]; then
		printf "   Processor temperature: %s\n" "$(/usr/bin/sensors -A | grep CPU)"
	else
		if [[ ${F_VERBOSE} == TRUE ]]; then
			printf "  * Notice: cannot execute 'sensors'.\n"
		fi
	fi

	# Running processes
	printf " == Checking process states\n"
	for PROCSTATE in ${L_PROCSTATES}; do
		L_PROCSTATECOUNT=$(ps -eo state | grep ${PROCSTATE} | awk 'NF { print $1 }' | tr "\n" " ")
		if [[ ! -z ${L_PROCSTATECOUNT} || ${F_VERBOSE} == TRUE ]]; then
			case "${PROCSTATE}" in
				D)
					printf "   %s process(es) in uninterruptible sleep\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				R) 
					printf "   %s process(es) on run queue\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				S)
					printf "   %s process(es) in interruptible sleep, waiting for an event to complete\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				T)
					printf "   %s process(es) stopped, either by a job control signal or because they are being traced\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				W)
					printf "   %s process(es) paging (not valid since the 2.6.xx kernel)\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				X)
					printf "   %s DEAD process(es); these should not exist!\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				Z)
					printf "   %s ZOMBIE process(es); defunct, terminated but not reaped by its parent\n" "$(countelements ${L_PROCSTATECOUNT})"
					;;
				*)
					printf "   %s process(es) with an UNDEFINED state: %s\n" "$(countelements ${L_PROCSTATECOUNT})" "${PROCSTATE}"
					;;
			esac
		fi
		L_PROCSTATECOUNT=0
	done
	PROCSTATE=""

  # Memory
   if [[ -x /usr/bin/free ]]; then
      printf " == Overview of memory usage [MB]: \n"
      if [[ ${F_VERBOSE} == TRUE ]]; then
         /usr/bin/free -mt | awk 'NF {print "     "$0}' 
       else
         /usr/bin/free -mt | grep -E 'Total|total' | awk 'NF {print "     "$0}' 
      fi
    else
      printf " ** ERROR: cannot check memory usage using 'free'.\n"
   fi

  # Software packages; requires 'apt-show-versions' package
   if [[ -x /usr/bin/apt-show-versions ]]; then
      printf " == Checking software versions..."
      L_SWUPDATE=$(apt-show-versions -u -b | awk '{ gsub("/"," ",$0); print $1 } ' | tr "\n" " ")
      if [[ $(countelements ${L_SWUPDATE}) == 0 ]]; then
         printf " no upgrades required.\n"
       else
	 printf " %s" ${L_SWUPDATE}
	 printf " (%s packages) can be upgraded.\n" "$(countelements ${L_SWUPDATE})"
      fi
    else
      if [[ ${F_VERBOSE} == TRUE ]]; then
         printf " ** Notice: cannot check installed software versions using 'apt-show-versions'.\n"
      fi
   fi
   pause

  # Virtual machines; requires libvirt & virsh
   if [[ -x /usr/bin/virsh ]]; then
      printf " == Virtual machine hosting service: "
      if [[ -x "/usr/sbin/service" ]]; then
         service libvirt-bin status
       else
         printf "\n  * ERROR: cannot execute 'service' to obtain virtual machine hosting service status.\n"
      fi
      virsh list --all | awk 'NF {print "     "$0}' | grep -v "\-\-\-"
    else
      if [[ ${F_VERBOSE} == TRUE ]]; then
         printf " ** Notice: cannot execute 'virsh' to check virtual machines.\n"
      fi
   fi

fi

#### STORAGE
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "storage" ]]; then
   printf "==== CHECK 2. STORAGE \n"

  # Local hard disks, requires 'smartmontools'
   if [[ -x /usr/sbin/smartctl ]]; then
      L_HDDs=$(smartctl --scan | awk 'NF { print $1 }' | tr "\n" " ")
      if [[ -z ${L_HDDs} ]]; then
         printf " ** Warning: no hard disks found.\n"
       else
         printf " == Hard disks found (%s): " "$(countelements ${L_HDDs})"
         printf " %s" ${L_HDDs}
         printf ".\n"
      fi
    else
      printf " ** Warning: cannot execute 'smartctl' for SMART HDD monitoring.\n"
   fi

  # RAID Status
   if [[ -r /proc/mdstat ]]; then
      printf " == Kernel raid state from /proc/mdstat:\n"
      if [[ ${F_VERBOSE} == TRUE ]]; then
         cat /proc/mdstat | awk 'NF { print "     "$0 } '
       else
         cat /proc/mdstat | awk 'NF { print "     "$0 } ' | grep -v "Personalities" | grep -v "unused devices"
      fi
    else
      printf " ** Warning: cannot read '/proc/mdstat'.\n"
   fi

  # Local files systems
   printf " == File systems overview: \n"
   if [[ -x "/bin/df" ]]; then
      if [[ ${F_VERBOSE} == TRUE ]]; then
         df -lhT | awk 'NF {print "     "$0}'
       else
         df -lhx tmpfs | awk 'NF {print "     "$0}'
      fi
    else
      printf "  * ERROR: cannot execute 'df' to obtain file system information.\n"
   fi

  # Samba status, requires 'samba' (duhhh)
   if [[ -x "/usr/bin/smbstatus" ]]; then
      printf " == Samba file server (%s): " "$(smbstatus -V)"
      if [[ -x "/usr/sbin/service" ]]; then
         service smbd status
       else
         printf "\n  * ERROR: cannot execute 'service' to obtain Samba service status.\n"
      fi
      if [[ $(whoami) != root ]]; then
         printf "  * Notice: not root; could not obtain detailed status about Samba shares.\n"
       else
         smbstatus -S | awk 'NF {print "     "$0}' | grep -v "\-\-\-"
      fi
    else
      printf " ** Notice: cannot execute 'smbstatus' to check Samba file server status.\n"
   fi
   pause
fi

#### NETWORK
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "network" ]]; then
   printf "==== CHECK 3. NETWORK \n"

  # Interfaces
   L_IFs=$(ls -1 /sys/class/net/ | awk 'NF { print $1 }' | tr "\n" " ")
   if [[ -z ${L_IFs} ]]; then
      printf " ** Warning: no network interfaces found.\n"
    else
      printf " == Network interfaces found (%s): " "$(countelements ${L_IFs})"
      printf " %s" ${L_IFs}
      printf ".\n"

      if [[ ${F_VERBOSE} == TRUE ]]; then
	 ifconfig | grep -E "Link|inet" | awk 'NF {print "      "$0}'
         ifconfig -s | awk 'NF {print "     "$0}'
      fi
   fi

  # Show open server ports
   if [[ -x /bin/netstat ]]; then

      printf " == Network connections:\n"
      # List established connections
      netstat -tp 2> /dev/null | awk 'NF {print "     "$0}'

      # Verbose option also lists open ports listening
      if [[ ${F_VERBOSE} == TRUE ]]; then
         netstat -tlp 2> /dev/null | awk 'NF {print "     "$0}'
      fi

      # Tell why no PID is given when not root
      if [[ $(whoami) != root ]]; then
         printf "  * Notice: not root; could not obtain PID/Program associated with each port.\n"
      fi

    else
      printf " ** ERROR: cannot execute 'netstat'.\n"
   fi

  # DHCP Server: isc-dhcp-server
   printf " == Dynamic Host Confguration Protocol (DHCP) server: "
   if [[ -x "/usr/sbin/service" ]]; then
      service isc-dhcp-server status
    else
      printf "\n  * ERROR: cannot execute 'service' to obtain DHCP server status.\n"
   fi

  # DNS Server: bind9
   printf " == Domain Name System (DNS) server: "
   if [[ -x "/usr/sbin/service" ]]; then
      service bind9 status
    else
      printf "'\n  * ERROR: cannot execute 'service' to obtain DNS server status.\n"
   fi

  # NTP Server
   printf " == Network Time Protocol (NTP) server: "
   if [[ -x "/usr/sbin/service" ]]; then
      service ntp status
    else
      printf "\n  * ERROR: cannot execute 'service' to obtain NTP server status.\n"
   fi
   if [[ ${F_VERBOSE} == TRUE ]]; then
      if [[ -x /usr/bin/ntpq ]]; then
         ntpq -c peers | awk 'NF { print "     "$0 }' | grep -v "==="
      fi
   fi

pause
fi

#### SECURITY
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "security" ]]; then
   printf "==== CHECK 4. SECURITY \n"

   if [[ -x "/usr/bin/last" ]]; then
      printf " == Last logins: \n"
      last -5 | awk 'NF { print "     "$0 }' | grep -v wtmp
    else
      printf "  * ERROR: cannot execute 'last' to obtain latest logins. \n"
   fi

   if [[ $(whoami) == root ]]; then

  # AppArmor
      if [[ ${F_VERBOSE} == TRUE ]]; then
         printf " == AppArmor status: "
         if [[ -x "/usr/sbin/service" ]]; then
            service apparmor status | awk 'NF { print "     "$0 }'
          else
            printf "\n  * ERROR: cannot execute 'service' to obtain status.\n"
         fi
      fi

  # Firewall
      printf " == Firewall status: "
      if [[ -x "/usr/sbin/service" ]]; then
         service ufw status
       else
         printf "\n  * ERROR: cannot execute 'service' to obtain status.\n"
      fi

      if [[ -x "/usr/sbin/ufw" ]]; then
         ufw status verbose | awk 'NF { print "     "$0 }' | grep -v "\-\-\|Logging\|profile"
       else
         printf "  * WARNING: connot execute 'ufw' to check firewall.\n"
      fi

    else
      printf " ** Notice: not root; cannot check further security status.\n"
   fi

fi

#### WEB SERVICES
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "web" ]]; then
   printf "==== CHECK 5. WEB SERVICES \n"

  # Apache Server
   if [[ -x "/usr/sbin/apache2" ]]; then
      printf " == Apache web server (%s): " "$(apache2 -v | grep version)"
      if [[ -x "/usr/sbin/service" ]]; then
         service apache2 status
       else
         printf "\n  * ERROR: cannot execute 'service' to obtain Apache web server status.\n"
      fi
     else
      printf " ** Notice: cannot execute 'apache2' to check Apache web server status.\n"
   fi
  # Pound reverse proxy 
   printf " == Pound reverse proxy server: "
   if [[ -x "/usr/sbin/service" ]]; then
      service pound status
    else
      printf "\n  * ERROR: cannot execute 'service' to obtain Pound proxy server status)\n"
   fi

pause
fi

#### DATABASE
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "database" ]]; then
   printf "==== CHECK 6. DATABASE \n"

  # MySQL Server
   printf " == MySQL database server: "
   if [[ -x "/usr/sbin/service" ]]; then
      service mysql status
    else
      printf "\n  * ERROR: cannot execute 'service' to obtain MySQL server status)\n"
   fi

pause
fi

#### E-MAIL and PIM
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "pim" ]]; then
   printf "==== CHECK 7. E-MAIL & PIM \n"

  # PIM Service
   printf " ** Notice: contacts & calender are provided by the ownCloud web service\n"

  # E-mail Service
   printf " ** Notice: no e-mail service configured\n"

fi

#### MEDIA
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "media" ]]; then
   printf "==== CHECK 8. MEDIA \n"

  # DLNA Server
   if [[ -x "/usr/bin/minidlnad" ]]; then
      printf " == DLNA media server (%s): " "$(minidlnad -V | grep Version)"
      if [[ -x "/usr/sbin/service" ]]; then
         service minidlna status
       else
         printf "\n  * ERROR: cannot execute 'service' to obtain DLNA server status)\n"
      fi
    else
      printf " ** Notice: cannot execute 'minidlnad' to check DLNA media server status.\n"
   fi
fi

#### DOMOTICA
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "domo" ]]; then
   printf "==== CHECK 9. DOMOTICA \n"

  # OpenHAB Server
   printf " == OpenHAB domotica server: "
   if [[ -x "/usr/sbin/service" ]]; then
      service openhab status
    else
      printf "\n  * ERROR: cannot execute 'service' to obtain OpenHAB server status)\n"
   fi
fi

# That is all
printf "All status checks completed.\n"
exit 0
