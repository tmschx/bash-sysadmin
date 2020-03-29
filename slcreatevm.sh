#!/bin/bash
##
## /usr/local/script/slcreatevm.sh
## Create a kernel-based VM
##
## Created on 14 OCT 2013
## Version 1.0 dated 20 OCT 2013
##
## Arguments:
##  -h : shows usage
##  -t : test mode
##  -i : iso-file to use
##  -o : overwrite existing VM
##

# Set variables and default values
set -u
EXITCODE=0          # Assume everything went ok
F_TEST=FALSE        # Script test flag
F_OVERWRITE=FALSE   # Overwrite previosu VM flag
VMINSTALLSCRIPT=""  # KVM installer
ARGUMENTFILE=""     # File with arguments for KVM installer
ISOFILE=""          # ISO-file
CMD_CREATEVM=""     # Command to execute and create VM
CMD_ARGVALSEP=" "   # Seprator between arguments and value on command line
argument[0]=""      # Array with arguments
value[0]=""         # Array with argument values

# Define functions
function checktocontinue() {
    # Ask to continue
    read -p "Continue (y/n)? " -n 1 -r
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        printf "\n"
    else
        printf "\nYou choose not to continue. Exiting.\n"
        exit 1
    fi
}

# Check if this script is run as root, otherwise exit.
if [[ $(whoami) != root ]]; then
    printf "Must be root to execute this script. Exiting.\n"
    exit 1
fi

# Evaluate given options using getops; set variables accordingly
while getopts "i:oth" opt; do
    case "$opt" in
        i)
            ISOFILE=${OPTARG}
            #printf -- "ISO-file specified: %s\n" "${ISOFILE}"
        ;;
        o)
            F_OVERWRITE=TRUE
            #printf -- "Previous VM will be overwritten."
        ;;
        t)
            F_TEST=TRUE
            printf -- "Test mode: script will only dry-run.\n"
        ;;
        \? | h)
            printf -- "Script for creating KVM guests to be run by the system libvirtd instance.\n"
            printf -- "Usage: %s [-h] [-t] [-o] [-i isofile] \n" "${0##*/}"
            printf -- "   -h   Help: show this help message and exit.\n"
            printf -- "   -t   Test mode: script will only dry-run.\n"
            printf -- "   -i   ISO-file: install KVM-guest from 'isofile' using virt-install.\n"
            printf -- "        If no ISO-file is specified, vmbuilder will be used to install a JeOS KVM-guest.\n"
            printf -- "   -o   Overwrite VM if already existing (vmbuilder only; virt-install should prompt).\n"
            printf -- "Required files in the current installation directory: \n"
            printf -- "   '<vmbuilder|virt-install>.arguments': file with arguments passed to the install command.\n"
            # printf -- "   'firstboot.sh': optional script to be run on first boot of the virtual machine.\n"
            # printf -- "   'firstlogin.sh': optional script to be used on first user login.\n"
            exit 2
        ;;
        :)
            printf -- "Option -%s requires an argument. Exiting.\n" "${OPTARG}"
            exit 1
        ;;
    esac
done

# Check install method and set-up initial command
if [[ -z "${ISOFILE}" ]]
then
    VMINSTALLSCRIPT="vmbuilder"
    CMD_ARGVALSEP=" "
    CMD_CREATEVM="${VMINSTALLSCRIPT} kvm ubuntu -v --libvirt qemu:///system "
    if [[ ${F_OVERWRITE} == TRUE ]]
    then
        CMD_CREATEVM="${CMD_CREATEVM} -o "
    fi
    printf "No ISO-file specified. Using '%s' to install a JeOS KVM-guest.\n"  ${VMINSTALLSCRIPT}
else
    VMINSTALLSCRIPT="virt-install"
    CMD_ARGVALSEP="="
    CMD_CREATEVM="${VMINSTALLSCRIPT} --connect=qemu:///system --cdrom=${ISOFILE} --check-cpu "
    printf "Using '%s' to install the OS from the specified ISO-file '%s'.\n"  ${VMINSTALLSCRIPT} ${ISOFILE}
fi
if [[ ! -x $(which "${VMINSTALLSCRIPT}") ]]
then
    printf "\nCannot execute %s. Have the required packages correctly been installed? Exiting.\n" ${VMINSTALLSCRIPT}
    exit 1
fi

# Check current directory
printf "Executing %s in %s. " "${VMINSTALLSCRIPT}" "$(pwd)"
checktocontinue

# Read arguments from file in current VM directory
ARGUMENTFILE="${VMINSTALLSCRIPT}.arguments"
if [[ -r "${ARGUMENTFILE}" ]]
then
    # Compile argument list from the first field of each record.
    i=0
    while read line; do
        if [[ "${line}" =~ ^[^#]*= ]]; then
            argument[i]="--"${line%% =*}
            value[i]=${line#*= }
            ((i++))
        fi
    done < ${ARGUMENTFILE}
    
    # Compile final command
    printf "The following %s arguments were specified in %s:\n" "${VMINSTALLSCRIPT}" "${ARGUMENTFILE}"
    j=0
    while [[ ${j} -lt ${i} ]]; do
        printf "   %s %s \n" ${argument[$j]} ${value[$j]}
        CMD_CREATEVM="${CMD_CREATEVM} ${argument[$j]}${CMD_ARGVALSEP}${value[$j]} "
        ((j++))
    done
    
    printf "Please check if these arguments are correct. "
    checktocontinue
else
    printf "Cannot read arguments from '%s'. Exiting.\n" "${ARGUMENTFILE}"
    exit 1
fi

printf "The following command will be executed: \n'%s'\n" "${CMD_CREATEVM}"
# Test or real?
if [[ ${F_TEST} == TRUE ]]
then
    # Test run only
    case "${VMINSTALLSCRIPT}" in
        vmbuilder)
            printf "Test mode specified, but vmbuilder cannot dry-run.\n"
        ;;
        virt-install)
            CMD_CREATEVM="${CMD_CREATEVM} --dry-run"
            printf "Test mode specified, so virt-install will dry-run only. "
            checktocontinue
            ${CMD_CREATEVM}
            EXITCODE=$?
        ;;
        *)
            printf "Error in script. Unknown install command %s.\nThis should not occur. Exiting." "${VMINSTALLSCRIPT}"
            exit -1
        ;;
    esac
else
    # The real thing
    printf "YOU ARE ABOUT TO CREATE A NEW KVM-GUEST. "
    checktocontinue
    ${CMD_CREATEVM}
    EXITCODE=$?
fi

# End of script; exit with exit-code of the real install script
printf "All done.\n"
exit ${EXITCODE}
