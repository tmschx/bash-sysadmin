#!/bin/bash
##
## /usr/local/script/slapt.sh
## Check and update software packages
##
## Created on 24 AUG 2014
## Version 1.1 dated 10 JUL 2015
##	- added trim for the root filesystem on a solid state drive
## VErsion 1.2 dated 02 SEP 2017
##	- replaced 'apt-get' with 'apt' where possible
##

# Set variables and default values
set -u
ERRORCODE=0			# We assume no errors will occur...

# Define functions
function checktocontinue() {
	# Ask to continue
	read -p "Continue (y/n)? " -n 1 -r
	if [[ "$REPLY" =~ ^[Yy]$ ]]; then
		printf "\n"
	else
		printf "\nYou choose not to continue. Exiting.\n"
		exit ${ERRORCODE}
	fi
}

# Check if this script is run as root, otherwise exit.
if [[ $(whoami) != root ]]; then
	printf "Must be root to execute this script. Exiting.\n"
	exit 1
fi

# Step 1: update 
printf "==== STEP 1. Update: resynchronizing the package index files from their sources
 specified in /etc/apt/sources.list; this may take a few moments...\n"
apt-get update -qq; ERRORCODE=$?
if [[ ${ERRORCODE} != 0 ]]; then
	printf " ** Error occured while updating package index files. "
	checktocontinue
else
	printf " == Done updating package index files.\n"
fi

# Step 2: autoclean
printf "==== STEP 2. Autoclean: clearing out the local repository of old package files
 that can no longer be downloaded.\n"
apt-get autoclean; ERRORCODE=$?
if [[ ${ERRORCODE} != 0 ]]; then
	printf " ** Error occured while autocleaning old packages from the local repository. "
	checktocontinue
else
	printf " == Done autocleaning old packages from the local repository.\n"
fi

# Step 3: Clean
printf "==== STEP 3. Clean: clearing out the local repository and cache.\n"
apt-get clean; ERRORCODE=$?
if [[ ${ERRORCODE} != 0 ]]; then
	printf " ** Error occured while cleaning the local repository. "
	checktocontinue
else
	printf " == Done cleaning the local repository.\n"
fi

# Step 4: Upgrade
printf "==== STEP 4. Upgrade: installing the newest versions of all packages currently installed
 on the system from the sources in /etc/apt/sources.list.\n"
apt upgrade; ERRORCODE=$?
if [[ ${ERRORCODE} != 0 ]]; then
	printf " ** Error occured while upgrading software packages."
	checktocontinue
else
	printf " == Done upgrading installed software pacakges.\n"
fi
sync

# Step 5: Autoremove
printf "==== STEP 5. Autoremove: removing packages that were automatically installed to satisfy
 dependencies for other packages and that are now no longer needed.\n"
apt-get autoremove; ERRORCODE=$?
if [[ ${ERRORCODE} != 0 ]]; then
	printf " ** Error occured while removing unused packages without dependencies. "
	checktocontinue
else
	printf " == Done removing unused software pacakges.\n"
fi

# Step 6: Trim filesystem
printf "==== STEP 6. Filesystem TRIM for Solid State Drives.\n  "
sync
ROOTDEVICE=$(findmnt -n -o SOURCE /)
if [[ ! -z $(hdparm -I $ROOTDEVICE | grep "TRIM supported") ]]; then
	fstrim -v /
fi

# End of script
printf "All done. Exiting.\n"
exit 0
