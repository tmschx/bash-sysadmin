#!/bin/bash
##
## /usr/local/script/slbackup.sh
## Backup files to an external device
##
## Created on 02 DEC 2012
## Version 1.3 dated 26 JUL 2015
##  - added encryption by default using OpenPGP 128 bit AES without compression
##  - added checksum generation using faster CRC checksum (instead of a secure hash)
##  - added help message explaining all options and defaults
##  - minor improvements and code cleanup
## Version 1.4 dated 14 MAY 2018
##  - made checksum optional
##
## Argurments:
##  -t : test mode
##  -c : specify the configuration file listing the items to backup
##  -i : specify a single item to backup, which must listed in the configuration file
##  -d : specify a backup device, if not yet mounted.\n"
##  -m : specify mountpoint to use. Default is %s.\n" ${BUMOUNTPOINT}
##  -s : calculates CRC checksum of the backup
##  -n : does NOT encrypt backup archives
##  -r : removes old backup archives from backup device after each succesful backup
##  -h : displays usage
##

# Set variables; all other variables are kept unset on purpose!
set -u
F_BUTEST=FALSE              # Script test flag
F_BUENCRYPT=TRUE            # Encrypt backups by default
F_BUREMOVE=FALSE            # Do not remove old backups by default
F_CHECKSUM=FALSE            # Do not calculate checksum
BUDEVICE=""                 # By default no device will be mounted
BUITEM=""                   # By default no item specified
L_BUITEMS=""                # Clear list with backup items
L_BUREMOVE=""               # Clear items to remove
BULOGFILE="/var/log/backup" # Logfile
BUKEYFILE="/etc/bukey"      # Password file
BUCONFIGFILE="/etc/backups" # Default configuration file
BUMOUNTPOINT="/backup"      # Default mountpoint of backup device

# Evaluate given options using getops; set variables accordingly
while getopts "c:d:m:i:nrht" opt; do
    case "$opt" in
        \? | h)
            printf -- "Backup entire directories with their subdirecties to an encrypted archive on a removable device.\n"
            printf -- "Usage: %s [-t] [-c <configuration file>] [-i <backup item>]\n" ${0##*/}
            printf -- "          [-d <device>] [-m <mountpoint>] [-n] [-r] [-h]\n"
            printf -- "  -t  Test mode: backup script will only dry-run. Specifically: backups are written to /dev/null,\n"
            printf -- "       no old archives are actually removed, but checksums of all archives will be (re)calculated.\n"
            printf -- "  -c  Specify the configuration file listing the items to backup. Default is %s.\n" ${BUCONFIGFILE}
            printf -- "  -i  Specify a single item to backup, which must listed in the configuration file. Default is all items.\n"
            printf -- "  -d  Specify a backup device, if not yet mounted.\n"
            printf -- "  -m  Specify mountpoint to use. Default is %s.\n" ${BUMOUNTPOINT}
            printf -- "  -s  Calculate CRC checksum of the backup using 'cksum'. Default is no checksum.\n"
            printf -- "  -n  Do NOT encrypt backup archives. Default is 128-bit AES encryption using OpenPGP.\n"
            printf -- "       The encryption password should be in %s.\n" ${BUKEYFILE}
            printf -- "  -r  Remove old backup archives from backup device after each succesful backup.\n"
            printf -- "  -h  Print this help message and exit.\n"
            printf -- "Must be root to execute %s.\n" ${0##*/}
            printf -- "Logs are written to %s.\n" ${BULOGFILE}
            exit 3
        ;;
        t)
            F_BUTEST=TRUE
            printf -- "Test mode specified with -t: backup script will only dry-run.\n"
        ;;
        c)
            BUCONFIGFILE=${OPTARG}
            printf -- "Configuration file specified with -c: %s\n" ${BUCONFIGFILE}
        ;;
        d)
            BUDEVICE=${OPTARG}
            printf -- "Backup device specified with -d: %s\n" ${BUDEVICE}
        ;;
        m)
            BUMOUNTPOINT=${OPTARG}
            printf -- "Backup mountpoint specified with -m: %s\n" ${BUMOUNTPOINT}
        ;;
        n)
            F_BUENCRYPT=FALSE
            printf -- "Encryption disabled with -n.\n"
        ;;
        s)
            F_CHECKSUM=TRUE
            printf -- "Checksum calculation enabled with -s.\n"
        ;;
        i)
            BUITEM=${OPTARG}
            printf -- "Backup item specified with -i: %s\n" ${BUITEM}
        ;;
        r)
            F_BUREMOVE=TRUE
            printf "Option set to remove old backup archives from %s.\n" ${BUMOUNTPOINT}
        ;;
        :)
            printf -- "Option -%s requires an argument. Exiting." ${OPTARG}
            exit 2
        ;;
    esac
done

# Check if this script is run as root, otherwise exit.
if [[ $(whoami) != root ]]
then
    printf "Must be root to execute this script. Exiting.\n"
    exit 2
fi

# Start new log entry
echo "$(date): ===== New session =====" >> "${BULOGFILE}"
echo "$(date): ${0} invoked with: ${@} " >> "${BULOGFILE}"

# Check if tar is executable
if [[ ! -x $(which tar) ]]
then
    printf "Cannot execute the tar command.\n Please check your installed packages or path. Exiting.\n" | tee -a "${BULOGFILE}"
    echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
    exit 1
fi

# Check encryption
if [[ ${F_BUENCRYPT} == TRUE ]]
then
    # Check for OpenPGP installation
    if [[ ! -x $(which gpg) ]]
    then
        printf -- "Cannot determine if OpenPGP is installed. Use -n to disable encrytpion. Exiting.\n" | tee -a "${BULOGFILE}"
        echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
        exit 1
    fi
    # Check for passwordfile
    if [[ ! -r ${BUKEYFILE} ]]
    then
        printf -- "Cannot read required password file %s for encryption. Exiting.\n" ${BUKEYFILE}  | tee -a "${BULOGFILE}"
        echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
        exit 1
    fi
fi

# Prepare checksums
if [[ -x $(which cksum) && -x $(which sha256sum) ]]
then
    BUTIMESTAMP="$(date '+%y%m%d_%H%M')"
    BUCHECKSUMFILE1="${BUMOUNTPOINT}/_checksums.${BUTIMESTAMP}.txt"
    BUCHECKSUMFILE2="${BUMOUNTPOINT}/_checksums.${BUTIMESTAMP}.hash.gpg"
else
    printf "Cannot execute cksum or sha256sum to generate checksums.\n Please check your installed packages or path. Exiting.\n" | tee -a "${BULOGFILE}"
    echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
    exit 1
fi

# Read the backup configuration from the configuration file
if [[ -f ${BUCONFIGFILE} ]]
then
    # Check if -i option is used and back item is already specified
    if [[ -z ${BUITEM} ]]
    then
        # Compile a list of backup items from the
        # first field of each record. Records with '#' in
        # the first field are ignored / treated as comments.
        L_BUITEMS=$(awk '$1 !~ /#/ { print $1 }' "${BUCONFIGFILE}" | tr "\n" " ")
        # Print the result, if any.
        if [[ -z ${L_BUITEMS} ]]
        then
            printf "No items to back up found in %s.\n" ${BUCONFIGFILE} | tee -a "${BULOGFILE}"
            echo "$(date): ${0} could not find anything to backup." >> "${BULOGFILE}"
        else
            printf "Configuration file %s contains the following backup items:\n" ${BUCONFIGFILE} | tee -a "${BULOGFILE}"
            printf "  %s" ${L_BUITEMS} | tee -a "${BULOGFILE}"
            printf "\n" | tee -a "${BULOGFILE}"
        fi
    else
        # List of backup items only conatins specified item
        L_BUITEMS="${BUITEM}"
    fi
else
    # Configuration file does not exist; exit.
    printf "Configuration file %s does not exist. Exiting.\n" ${BUCONFIGFILE} | tee -a "${BULOGFILE}"
    echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
    exit 1
fi

# Check default mountpoint for the backup device.
printf "Checking backup device mountpoint %s... " ${BUMOUNTPOINT} | tee -a "${BULOGFILE}"
if [[ ! -d ${BUMOUNTPOINT} ]]
then
    printf "not existing. Exiting.\n" | tee -a "${BULOGFILE}"
    echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
    exit 1
fi
/bin/mountpoint -q "${BUMOUNTPOINT}" 2>>"${BULOGFILE}"
if [[ ${?} == 0 ]]
then    # Something is mounted...
    if [[ -z ${BUDEVICE} ]]
    # ... and no device specified, so we use whatever is mounted.
    then
        printf "OK.\n" | tee -a "${BULOGFILE}"
        # ... and a device has been specified; not sure if that one is mounted.
    else
        printf "already used.\n" | tee -a "${BULOGFILE}"
        printf "Cannot mount %s. Exiting.\n" ${BUDEVICE}
        echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
        exit 1
    fi
else    # Nothing mounted...
    if [[ -z ${BUDEVICE} ]]
    then    # ... and no device to mount specified.
        printf "nothing mounted.\n" | tee -a "${BULOGFILE}"
        printf "No backup device specified to mount. Exiting.\n"
        echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
        exit 1
    else    # ... try to mount he specified device.
        printf "mounting %s... " ${BUDEVICE} | tee -a "${BULOGFILE}"
        /bin/mount "${BUDEVICE}" "${BUMOUNTPOINT}" &>> "${BULOGFILE}"
        if [[ ${?} == 0 ]]
        then
            printf "OK.\n" | tee -a "${BULOGFILE}"
        else
            printf "Error.\n" | tee -a "${BULOGFILE}"
            printf " See %s for details. Exiting.\n" ${BULOGFILE}
            echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
            exit 1
        fi
    fi
fi
# Show content of backup device
df -hl "${BUMOUNTPOINT}" | tee -a "${BULOGFILE}"

for BUITEM in ${L_BUITEMS}; do
    
    # Compile backup item names
    BUSOURCE="$(awk -v buitem=${BUITEM} '$1 == buitem { print $2 }' ${BUCONFIGFILE} | head -1 )"
    BUTIMESTAMP="$(date '+%y%m%d_%H%M')"
    if [[ ${F_BUENCRYPT} == TRUE ]]
    then
        BUFILE="${BUMOUNTPOINT}/${BUITEM}_${BUTIMESTAMP}.tar.gpg"
    else
        BUFILE="${BUMOUNTPOINT}/${BUITEM}_${BUTIMESTAMP}.tar"
    fi
    
    # Check backup source directory
    if [[ -d ${BUSOURCE} ]]
    then
        # Perform backup if source directory exists
        BUSIZE=$(du -sb ${BUSOURCE} | awk '{ print $1 }')
        printf -- "Backing up %s MB from %s to %s... " $((${BUSIZE} >> 20)) ${BUSOURCE} ${BUFILE}  | tee -a "${BULOGFILE}"
        
        if [[ ${F_BUTEST} == TRUE ]]
        then
            # For test runs set output to /dev/null
            BUFILEORG=${BUFILE}
            BUFILE="/dev/null"
            printf "(test run only)" | tee -a "${BULOGFILE}"
        fi
        printf "\n" | tee -a "${BULOGFILE}"
        
        # Perform the actual backup archiving and encryption, with progress bar if available
        sync
        if [[ -x $(which pv) ]]
        then
            # Progress bar
            if [[ ${F_BUENCRYPT} == TRUE ]]
            then
                # Backup with encryption and progress bar
                tar -cplf - "${BUSOURCE}"  2>> "${BULOGFILE}" |\
                gpg --symmetric --cipher-algo AES --passphrase-file ${BUKEYFILE} --compress-algo none --no-use-agent --batch --yes --quiet 2>> "${BULOGFILE}" |\
                pv -N "Progress" -s ${BUSIZE} \
                > "${BUFILE}"
                # Preserve exit codes
                EXITSTATUS=(${PIPESTATUS[@]})
                C_TAREXIT="${EXITSTATUS[0]}"
                C_GPGEXIT="${EXITSTATUS[1]}"
            else
                # Backup with progress bar without encryption
                tar -cplf - "${BUSOURCE}"  2>> "${BULOGFILE}" |\
                pv -N "Progress" -s ${BUSIZE} \
                > "${BUFILE}"
                # Preserve exit code
                EXITSTATUS=(${PIPESTATUS[@]})
                C_TAREXIT="${EXITSTATUS[0]}"
                C_GPGEXIT=-1
            fi
        else
            # No progress bar
            printf " No progress bar. Large back-ups can take more than 15 mins. Please be patient... \n"
            if [[ ${F_BUENCRYPT} == TRUE ]]
            then
                # Backup with encryption without progress bar
                tar -cplf - "${BUSOURCE}"  2>> "${BULOGFILE}" |\
                gpg --symmetric --cipher-algo AES --passphrase-file ${BUKEYFILE} --compress-algo none --no-use-agent --batch --yes --quiet 2>> "${BULOGFILE}" \
                > "${BUFILE}"
                # Preserve exit codes
                EXITSTATUS=(${PIPESTATUS[@]})
                C_TAREXIT="${EXITSTATUS[0]}"
                C_GPGEXIT="${EXITSTATUS[1]}"
            else
                # Backup without encryption and without progress bar
                tar -cplf - ${BUSOURCE} 2>> "${BULOGFILE}" \
                > "${BUFILE}"
                # Preserve exit codes
                C_TAREXIT="$?"
                C_GPGEXIT=-1
            fi
        fi
        sync
        if [[ ${F_BUTEST} == TRUE ]]
        then
            BUFILE="${BUFILEORG}"
        fi
        
        # Assume no success...
        F_BUSUCCESS=FALSE
        # Check first for OpenPGP encryption errors...
        if [[ ${C_GPGEXIT} > 0 ]]
        then
            printf " Error while encryting backup archive %s.\n" ${BUFILE} | tee -a "${BULOGFILE}"
            printf "  See %s for details.\n" ${BULOGFILE}
        else
            # ... then check for tar errors.
            case ${C_TAREXIT} in
                0)
                    printf " Successfully created backup archive %s.\n" ${BUFILE} | tee -a "${BULOGFILE}"
                    F_BUSUCCESS=TRUE
                ;;
                1)
                    printf " Created backup archive %s with minor errors." ${BUFILE} | tee -a "${BULOGFILE}"
                    printf "  See %s for details.\n" ${BULOGFILE}
                    F_BUSUCCESS=TRUE
                ;;
                2)
                    printf " Encountered errors while creating backup archive %s." ${BUFILE} | tee -a "${BULOGFILE}"
                    printf "  See %s for details.\n" ${BULOGFILE}
                ;;
                *)
                    printf " Unknown result creating backup archive %s.\n" ${BUFILE} | tee -a "${BULOGFILE}"
                    printf "  %s might contain details.\n" ${BULOGFILE}
                ;;
            esac
        fi
        
        # Calculate checksum
        if [[ ${F_CHECKSUM} == TRUE && ${F_BUSUCCESS} == TRUE && ${F_BUTEST} == FALSE ]]
        then
            printf " Calculating checksum for %s (might take a while)..." ${BUFILE} | tee -a "${BULOGFILE}"
            echo >> ${BULOGFILE}
            cksum ${BUFILE} 2>> "${BULOGFILE}" >> "${BUCHECKSUMFILE1}"
            if [[ ${?} == 0 ]]
            then
                printf "  Success.\n" | tee -a "${BULOGFILE}"
            else
                printf "  Error." | tee -a "${BULOGFILE}"
                printf " See %s for details.\n" ${BULOGFILE}
                echo >> ${BULOGFILE}
            fi
        fi
        
        # Remove old backup items
        if [[ ${F_BUREMOVE} == TRUE ]]
        then
            if [[ ${F_BUSUCCESS} == TRUE ]]
            then
                # Remove .tar-files from current backup item,
                # but NOT with latest (current) timestamp
                L_BUREMOVE=$(ls -1 ${BUMOUNTPOINT} | grep ${BUITEM} | grep -v ${BUTIMESTAMP} | tr "\n" " ")
                if [[ ! -z ${L_BUREMOVE} ]]
                then
                    printf " Removing old backup archives: \n" | tee -a "${BULOGFILE}"
                    for BUREMOVE in ${L_BUREMOVE}; do
                        BUREMOVE="${BUMOUNTPOINT}/${BUREMOVE}"
                        printf "   %s..." ${BUREMOVE} | tee -a "${BULOGFILE}"
                        if [[ ${F_BUTEST} == TRUE ]]
                        then
                            # Do NOT remove archive if it is a test run.
                            printf "(test run: nothing removed).\n" | tee -a "${BULOGFILE}"
                        else
                            # DO remove if no test run.
                            rm -f "${BUREMOVE}" 2>> "${BULOGFILE}"
                            if [[ "$?" == 0 ]]
                            then
                                printf "  Success.\n" | tee -a "${BULOGFILE}"
                            else
                                printf "  No success."  | tee -a "${BULOGFILE}"
                                printf " See %s for details.\n" "${BULOGFILE}"
                                echo >> ${BULOGFILE}
                            fi
                            sync
                        fi
                        # Remove next old archive
                    done
                fi
            else
                # Backup was not (fully) succesful; don't remove anything
                printf " Backup not (fully) successful; not removing old backup archives.\n"  | tee -a "${BULOGFILE}"
            fi
        fi
    else
        # Specified backup source does not exist
        printf -- "Backup source location %s does not exist or is no directory. Skipping.\n" ${BUSOURCE} | tee -a "${BULOGFILE}"
    fi
    # Reset variables with unqiue item data to avoid any damage with wrong data
    unset EXITSTATUS
    unset C_TAREXIT
    unset C_GPGEXIT
    unset F_BUSUCCESS
    unset BUSOURCE
    unset BUFILE
    unset BUFILEORG
    unset BUSIZE
    unset BUTIMESTAMP
    unset L_BUREMOVE
    # Next backup item
done

if [[ -e ${BUCHECKSUMFILE1} ]]
then
    # Copy checksums into logfile
    cat ${BUCHECKSUMFILE1} >> ${BULOGFILE}
    
    # Sign checksums with an encrypted hash of the file containing all checksums
    printf "Signing checksum file %s with an AES encrypted SHA-256 hash..." ${BUCHECKSUMFILE1} | tee -a "${BULOGFILE}"
    echo >> ${BULOGFILE}
    
    # Two hashes are created: one random (against known plaintext attacks) and one of the file containing all checksums...
    # ... and then they are encrypted together in a single file.
    sha256sum <(strings < /dev/urandom | head -c64) ${BUCHECKSUMFILE1} 2>> "${BULOGFILE}" |\
    gpg --symmetric --cipher-algo AES256 --passphrase-file ${BUKEYFILE} --compress-algo none --no-use-agent --batch --yes --quiet 2>> "${BULOGFILE}" \
    > ${BUCHECKSUMFILE2}
    
    # Preserve exit codes and check for errors.
    EXITSTATUS=(${PIPESTATUS[@]})
    C_SHAEXIT="${EXITSTATUS[0]}"
    C_GPGEXIT="${EXITSTATUS[1]}"
    if [[ ${C_GPGEXIT} != 0 || ${C_SHAEXIT} != 0 ]]
    then
        printf "  Error." | tee -a "${BULOGFILE}"
        printf " See %s for details.\n" ${BULOGFILE}
        echo >> ${BULOGFILE}
    else
        printf "  Success.\n" | tee -a "${BULOGFILE}"
    fi
else
    # No checksum file exists.
    printf "No checksum file created.\n" | tee -a "${BULOGFILE}"
fi

# Done. Print content summary.
sync
printf "Backup completed.\n Summary and contents of backup device:  " | tee -a "${BULOGFILE}"
echo >> ${BULOGFILE}
df -hl "${BUMOUNTPOINT}" | grep "/dev/" | tr -d "\n" | tee -a "${BULOGFILE}"
ls -lh "${BUMOUNTPOINT}" | awk '{ printf " %s %2s %6s %8s   %s\n", $6, $7, $8, $5, $9 }' | tee -a "${BULOGFILE}"

# Unmount if device was specified.
if [[ ! -z ${BUDEVICE} ]]
then
    printf "Unmounting %s from %s... " ${BUDEVICE} ${BUMOUNTPOINT} | tee -a "${BULOGFILE}"
    umount "${BUMOUNTPOINT}" &>> "${BULOGFILE}"
    if [[ $? -eq 0 ]]
    then
        printf "OK.\n" | tee -a "${BULOGFILE}"
    else
        printf "Error.\n"  | tee -a "${BULOGFILE}"
        printf " See %s for details. Exiting.\n" ${BULOGFILE}
        echo "$(date): ${0} exits (code 1). " >> "${BULOGFILE}"
        exit 1
    fi
fi

# That is all
printf "All done. Exiting.\n"
echo "$(date): ${0} successfully completed." >> "${BULOGFILE}"
echo "$(date): ===== End session =====" >> "${BULOGFILE}"
exit 0
