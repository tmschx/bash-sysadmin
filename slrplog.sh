#!/bin/bash
##
## /usr/local/script/slrplog.sh
## Filter unknown ip addresses from reverse proxy log
##
## Created on 10 JAN 2016
##
## Arguments:
##  -a : display all entries with unknown (untrusted) ip-addresses
##  -l : logfile tot analyse
##  -n : file with known (trusted) ip-addresses
##  -h : help message
##

# Set variables and default values
set -u
F_ALLUNKNOWN=FALSE                  # Flag to use all unknown ip's
FILTER="e503 no service"            # Log message to filter for
LOGFILE="/var/log/pound.log"        # Default logfile
TRUSTEDIPFILE="/srv/log/knownips"   # Default file with known ip's

# Evaluate given options using getops; set variables accordingly
while getopts "hal:n:" opt; do
    case "$opt" in
        \? | h)
            printf -- "Usage: %s [-a] [-l <logfile>] [-n <ipfile>] [-h]\n" "${0##*/}"
            printf -- "   -a   Display all entries instead of only 'e503 no back-end'.\n"
            printf -- "   -l   Use <logfile> instead of %s.\n" ${LOGFILE}
            printf -- "   -n   Use <ipfile> for trusted ip's instead of %s.\n" ${TRUSTEDIPFILE}
            printf -- "   -h   Help: show this help message and exit.\n"
            exit 2
        ;;
        a)
            F_ALLUNKNOWN=TRUE
        ;;
        l)
            LOGFILE="${OPTARG}"
        ;;
        n)
            TRUSTEDIPFILE="${OPTARG}"
        ;;
        :)
            printf -- "Option -%s requires an argument. Exiting." "${OPTARG}"
            exit 1
        ;;
    esac
done

# Check whether logfile exists
if [[ ! -e ${LOGFILE} ]]; then
    printf "Logfile '%s' does not exist. Exiting.\n" ${LOGFILE}
    exit 1
fi

# Check if file with trusted ip exists and filter accordingly
if [[ -e ${TRUSTEDIPFILE} ]]; then
    # Use trusted ip's to filter output
    printf -- "Using trusted ip addresses from: %s\n" "${TRUSTEDIPFILE}"
    if [[ ${F_ALLUNKNOWN} == FALSE ]]; then
        printf "Entries in '%s' with requests resulting in E503 No Service:\n" ${LOGFILE}
        grep "${FILTER}" ${LOGFILE} | grep -v -f ${TRUSTEDIPFILE}
    else
        printf "All entries in '%s' with unknown ip addresses:\n" ${LOGFILE}
        grep -v -f ${TRUSTEDIPFILE} ${LOGFILE}
    fi
else
    # Don't use trusted ip's to filter output
    printf "File with trusted ip addresses '%s' does not exist.\nA " ${TRUSTEDIPFILE}
    if [[ ${F_ALLUNKNOWN} == FALSE ]]; then
        printf "Entries in '%s' with requests resulting in E503 No Service:\n" ${LOGFILE}
        grep "${FILTER}" ${LOGFILE}
    else
        printf "All entries in '%s':\n" ${LOGFILE}
        cat ${LOGFILE}
    fi
fi

# End of script
exit 0
