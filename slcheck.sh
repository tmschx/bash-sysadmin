#!/bin/bash
##
## /usr/local/script/slcheck.sh
## Perform system checks
##
## Created on 25 MEI 2013
## Version 1.4 dated 12 MAR 2020
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
            printf -- "          [-f core | storage | network | security | services]\n"
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
    if [[ -x /usr/bin/lsb_release ]]; then
        printf " %s" "$(lsb_release -d | awk '{ print $2 }')"
        printf " %s" "$(lsb_release -r | awk '{ print $2 }')"
        printf " %s" "$(lsb_release -c | awk '{ print $2 }')"
    fi
    printf "\n"
    if [[ -x /bin/uname && /usr/bin/w && /bin/hostname ]]; then
        printf "   Hostname(s): %s\n" "$(hostname -A)"
        if [[ ${F_VERBOSE} == TRUE ]]; then
            uname -a | awk 'NF {print "     "$0}'
            w | awk 'NF {print "     "$0}'
        else
            w | head -n 1 | awk 'NF {print "     "$0}'
        fi
    else
        printf "  * ERROR: unable to execute basic unix commands to obtain system information.\n"
    fi
    # Hardware
    printf " == Hardware information\n"
    if [[ -x $(which sensors) ]]; then
        printf "   Processor temperature: %s\n" "$(/usr/bin/sensors -A | grep CPU)"
    else
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf "  * Notice: cannot find and/or execute 'sensors' to get hardware information.\n"
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
        printf " ** ERROR: cannot execute '/usr/bin/free' to check memory usage.\n"
    fi
    
    # Software packages; requires 'apt-show-versions' package
    if [[ -x $(which apt-show-versions) ]]; then
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
            printf " ** Notice: cannot find and/or execute 'apt-show-versions' to check installed software versions.\n"
        fi
    fi
    pause
    
    # Virtual machines; requires libvirt & virsh
    if [[ -x $(which virsh) ]]; then
        printf " == Virtual machine hosting service: "
        if [[ -x /usr/sbin/service ]]; then
            service libvirt-bin status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            printf "\n  * ERROR: cannot execute '/usr/sbin/service' to obtain virtual machine hosting service status.\n"
        fi
        virsh list --all | awk 'NF {print "     "$0}' | grep -v "\-\-\-"
    else
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " ** Notice: cannot find and/or execute 'virsh' to check virtual machines.\n"
        fi
    fi
    
fi

#### STORAGE
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "storage" ]]; then
    printf "==== CHECK 2. STORAGE \n"
    
    # Local hard disks, requires 'smartmontools'
    if [[ -x $(which smartctl) ]]; then
        L_HDDs=$(smartctl --scan | awk 'NF { print $1 }' | tr "\n" " ")
        if [[ -z ${L_HDDs} ]]; then
            printf " ** ERROR: no hard disks found.\n"
        else
            printf " == Hard disks found (%s): " "$(countelements ${L_HDDs})"
            printf " %s" ${L_HDDs}
            printf ".\n"
        fi
    else
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " ** Notice: cannot find and/or execute 'smartctl' for harddisk monitoring.\n"
        fi
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
    if [[ -x /bin/df ]]; then
        if [[ ${F_VERBOSE} == TRUE ]]; then
            df -lhT | awk 'NF {print "     "$0}'
        else
            df -lhx tmpfs | awk 'NF {print "     "$0}'
        fi
    else
        printf "  * ERROR: cannot execute '/bin/df' to obtain file system information.\n"
    fi
    
    # Samba status, requires 'samba' (duhhh)
    if [[ -x $(which smbstatus) ]]; then
        printf " == Samba file server (%s): " "$(nohup 2> /dev/null smbd -V)"
        if [[ -x /usr/sbin/service ]]; then
            service smbd status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            printf "\n  * ERROR: cannot execute '/usr/sbin/service' to obtain Samba service status.\n"
        fi
        if [[ $(whoami) != root ]]; then
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf "  * Notice: not root; could not obtain detailed status about Samba shares.\n"
            fi
        else
            smbstatus -S | awk 'NF {print "     "$0}' | grep -v "\-\-\-"
        fi
    else
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " ** Notice: cannot find and/or execute 'smbstatus' to check file server status.\n"
        fi
    fi
    pause
fi

#### NETWORK
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "network" ]]; then
    printf "==== CHECK 3. NETWORK \n"
    
    # Interfaces
    L_IFs=$(ls -1 /sys/class/net/ | awk 'NF { print $1 }' | tr "\n" " ")
    if [[ -z ${L_IFs} ]]; then
        printf " ** Warning: no network interfaces found in '/sys/class/net'.\n"
    else
        printf " == Network interfaces found (%s): " "$(countelements ${L_IFs})"
        printf " %s" ${L_IFs}
        printf ".\n"
        
        if [[ ${F_VERBOSE} == TRUE ]]; then
            ifconfig | grep -E "Link|inet" | awk 'NF {print "      "$0}'
            ifconfig -s | awk 'NF {print "     "$0}'
        fi
    fi

    # Virtual Private Network
    if [[ -x $(which nordvpn) ]]; then
        printf " == Virtual Private Network status:\n"
        nordvpn status 2> /dev/null | awk 'NF {print "     "$0}'
    fi
        

    # Show open server ports
    printf " == Network connections:\n"
    if [[ -x /bin/netstat ]]; then
        
        # List established connections
        netstat -tp 2> /dev/null | awk 'NF {print "     "$0}'
        
        # Verbose option also lists open ports listening
        if [[ ${F_VERBOSE} == TRUE ]]; then
            netstat -tlp 2> /dev/null | awk 'NF {print "     "$0}'
        fi
        
        # Tell why no PID is given when not root
        if [[ $(whoami) != root && ${F_VERBOSE} == TRUE ]]; then
            printf "  * Notice: not root; could not obtain process information for each port.\n"
        fi
        
    else
        printf "  * ERROR: cannot execute '/bin/netstat' to get network connections.\n"
    fi
    
    if [[ -x /usr/sbin/service ]]; then
        
        # DHCP Server: isc-dhcp-server
        if [[ -x $(which dhcpd) ]]; then
            printf " == Dynamic Host Confguration Protocol (DHCP) server (%s): " "$(nohup 2> /dev/null dhcpd --version)"
            service isc-dhcp-server status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'dhcpd' to check DHCP server status.\n"
            fi
        fi
        
        # DNS Server: bind9
        if [[ -x $(which named) ]]; then
            printf " == Domain Name System (DNS) server (%s): " "$(nohup 2> /dev/null named -v)"
            service bind9 status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'named' to check DNS server status.\n"
            fi
        fi
        
        # NTP Server
        if [[ -x $(which ntpd) ]]; then
            printf " == Network Time Protocol (NTP) server (%s): " "$(nohup 2> /dev/null ntpd --version)"
            service ntp status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'ntpd' to check NTP server status.\n"
            fi
        fi
        if [[ -x /usr/bin/ntpq && ${F_VERBOSE} == TRUE ]]; then
            ntpq -c peers | awk 'NF { print "     "$0 }' | grep -v "==="
        fi
        
        # Redirection Server 
        if [[ -x $(which rinetd) ]]; then
            printf " == Redirection Server (%s): " "$(nohup 2> /dev/null rinetd -v)"
            service rinetd status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'rinetd' to check redirection server status.\n"
            fi
        fi

    else
        printf " ** ERROR: cannot execute '/usr/sbin/service' to obtain status of network services.\n"
    fi
    
    pause
fi

#### SECURITY
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "security" ]]; then
    printf "==== CHECK 4. SECURITY \n"
    
    if [[ -x /usr/bin/last ]]; then
        printf " == Last logins: \n"
        last -5 | awk 'NF { print "     "$0 }' | grep -v wtmp
    else
        printf " ** ERROR: cannot execute '/usr/bin/last' to obtain latest logins. \n"
    fi
    
    if [[ $(whoami) == root ]]; then
        
        # AppArmor
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " == AppArmor status: "
            if [[ -x /usr/sbin/service ]]; then
                service apparmor status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
                printf "\n"
            else
                printf "\n  * ERROR: cannot execute '/usr/sbin/service' to obtain status.\n"
            fi
        fi
        
        # Firewall
        printf " == Firewall status: "
        if [[ -x /usr/sbin/service ]]; then
            service ufw status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            printf "\n  * ERROR: cannot execute '/usr/sbin/service' to obtain status.\n"
        fi
        
        if [[ -x $(which ufw) ]]; then
            ufw status verbose | awk 'NF { print "     "$0 }' | grep -v "\-\-\|Logging\|profile"
        else
            printf " ** Warning: cannot find and/or execute 'ufw' to check firewall.\n"
        fi
        
    else
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " ** Notice: not root; cannot verbosely check security status.\n"
        fi
    fi
    pause
fi

#### SERVICES
if [[ -z ${FUNCTIONCHECK} || ${FUNCTIONCHECK} == "services" ]]; then
    printf "==== CHECK 5. SERVICES \n"
    if [[ -x /usr/sbin/service ]]; then
        
        # Apache Server
        if [[ -x $(which apache2) ]]; then
            printf " == Web server (%s): " "$(nohup 2> /dev/null apache2 -v | grep version)"
            service apache2 status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf "  * Notice: status of individual web services using the web server are not shown.\n"
            fi
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'apache2' to check web server status.\n"
            fi
        fi
        
        # Pound reverse proxy
        if [[ -x $(which pound) ]]; then
            printf " == Reverse proxy (Pound %s): " "$(nohup 2> /dev/null pound -V | grep Version)"
            service pound status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'pound' to check reverse proxy status.\n"
            fi
        fi
        
        # MySQL Server
        if [[ -x $(which mysqld) ]]; then
            printf " == Database server (%s): " "$(nohup 2> /dev/null mysqld -V | grep Ver)"
            service mysql status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'mysqld' to check database server status.\n"
            fi
        fi
        
        # PIM Service
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " ** Notice: personal information services are provided as a web service.\n"
        fi
        
        # E-mail Service
        if [[ ${F_VERBOSE} == TRUE ]]; then
            printf " ** Notice: no e-mail service configured.\n"
        fi
        
        # DLNA Server
        if [[ -x $(which minidlnad) ]]; then
            printf " == Media server (MiniDLNA/ReadyMedia %s): " "$(nohup 2> /dev/null minidlnad -V | grep Version)"
            service minidlna status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: cannot find and/or execute 'minidlnad' to check media server status.\n"
            fi
        fi
        
        # OpenHAB Server
        if (service --status-all | grep -q openhab); then
            printf " == Domotica server (OpenHAB): "
            service openhab status | grep -E 'Active:|PID:' | awk '{print $2,$3} ' | tr '\n' ' '
            printf "\n"
        else
            if [[ ${F_VERBOSE} == TRUE ]]; then
                printf " ** Notice: service 'openhab' does not exist.\n"
            fi
        fi
        
    else
        printf " ** ERROR: cannot execute '/usr/sbin/service' to obtain status of services.\n"
    fi
fi

# That is all
printf "All status checks completed.\n"
exit 0
