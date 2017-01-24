#!/bin/bash
##
## /usr/local/script/slblockip.sh
## Add or remove ip-ranges to block by ufw
##
## Created on 21 JAN 2017
## Version 1.1 dated 22 JAN 2017
##
## Arguments:
##	-i <ip-range> : insert deny rule to ufw for <ip-range>
##	-d <ip-range> : delete ufw rules with <ip-range>
##	-a <file> : add deny rule to ufw for each ip-address range in <file>
##	-r <file> : remove ufw rules for each ip-address range in <file>
##	-h : displays usage
## IP-ranges are in cidr format, w.g. from http://www.ip2location.com
##

# Define functions
function checktocontinue {
	# Ask to continue
	read -p "Continue (y/n)? " -n 1 -r
	if [[ "$REPLY" =~ ^[Yy]$ ]]; then
		printf "\n"
	else
		printf "\nYou choose not to continue. Exiting.\n"
		exit ${ERRORCODE}
	fi
}

function printhelp {
	printf -- "Usage: %s -i <ip-range>|-d <ip-range>|-a <file>|-r <file> [-h]\n" ${0##*/}
	printf -- "  -i : insert deny rule to ufw for <ip-range>\n"
	printf -- "  -d : delete ufw rules with <ip-range>\n"
	printf -- "  -a : add deny rule to ufw for each ip-address range in <file>\n"
	printf -- "  -r : remove ufw rules for each ip-address range in <file>\n"
	printf -- "  -h : show usage\n"
	printf -- "IP-ranges are in cidr format.\n"
	printf -- "They can be obtained, for example, from http://www.ip2location.com.\n"
}

# Set variables and do not use unset variables
set -u

# Check if this script is run as root, otherwise exit.
if [[ $(whoami) != root ]]; then
	printf "Must be root to execute this script. Exiting.\n"
	exit 1
fi

# Check if no options
if [[ ! $@ =~ ^\-.+ ]]; then
	printhelp
	exit 2
fi

# Evaluate options
while getopts "i:d:a:r:h" opt; do
	case "$opt" in
		\? | h)
			printhelp
			exit 2
			;;
		i)
			IP_ADD=${OPTARG}
			printf -- "Adding ip-range %s to the firewall to deny. " ${IP_ADD}
			checktocontinue
			printf -- "Inserting rule to deny from %s... " ${IP_ADD}
			# Execute ufw command to add deny rule
			ufw insert 1 deny from ${IP_ADD} to any
			;;
		d)
			IP_DEL=${OPTARG}
			printf -- "Removing ip-range %s to the firewall to deny. " ${IP_DEL}
			checktocontinue
			printf -- "Delete rule to deny from %s... " ${IP_DEL}
			# Execute ufw command to add deny rule
			ufw delete deny from ${IP_DEL}
			;;
		a)
			FILE_ADD=${OPTARG}
			printf -- "Adding ip-ranges in file %s to the firewall to deny. " ${FILE_ADD}
			checktocontinue
			# Read the file line by line
			while read line; do
				# Check for comment lines
				if [[ ! ${line} =~ ^#+ ]]; then
					printf -- "Inserting rule to deny from %s... " ${line}
					# Execute ufw command to add deny rule
					ufw insert 1 deny from ${line} to any
				fi
			done < ${FILE_ADD}
			;;
		r)
			FILE_REMOVE=${OPTARG}
			printf -- "Removing ip-ranges in file %s from the firewall rules. " ${FILE_REMOVE}
			checktocontinue
			# Read the file line by line
			while read line; do
				# Check for comment lines
				if [[ ! ${line} =~ ^#+ ]]; then
					printf -- "Deleting rule for %s... " ${line}
					# Execute ufw command to remove ip-address from rules
					ufw delete deny from ${line}
				fi
			done < ${FILE_REMOVE}
			;;
		:)
			printf -- "Option -%s requires an argument. Exiting." "${OPTARG}"
			exit 1
			;;
	esac
done

# Done
printf "All done.\n"
exit 0
