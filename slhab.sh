#!/bin/bash
##
## /usr/local/script/slhab.sh
## OpenHAB CLI script
##
## Created on 14 FEB 2015
## Version 1.1 dated 15 FEB 2015
##
## Arguments:
##	-i <item> : item to be used
##	-c <command> : command to use; if no command state is obtained
##	-u <user> : alternate user
##	-t : test mode
##	-h : displays usage

# Set variables and default values
set -u
OHLOCALURLFILE="/srv/etc/openhab/url.cfg"
OHAUTHFILE="/srv/etc/openhab/users.cfg"
OHUSER=$(whoami)
OHAUTHSTR=""
OHITEM=""
OHCOMMAND=""
F_TEST=""
INITOPTSTR="-ksS"
HEADERSTR="Content-Type: text/plain"
EXEC=""
POSTEXECSTR=""

# Evaluate given options using getops; set variables accordingly
while getopts "i:c:u:ht" opt; do
      case "$opt" in
        \? | h)
          printf -- "Usage: %s -i <item> [-c <command>] [-u <user>] [-t] [-h]\n" ${0##*/}
          exit 2
          ;;
        t)
          F_TEST=TRUE
          #printf -- "Test mode: script will only print the curl command for the REST-interface.\n"
          ;;
        c)
          OHCOMMAND=${OPTARG}
          #printf -- "Command specified with -c: %s\n" ${OHCOMMAND}
          ;;
        u)
          OHUSER=${OPTARG}
          #printf -- "Alternate user specified with -u: %s\n" ${OHUSER}
          ;;
        i)
          OHITEM=${OPTARG}
          #printf -- "Item specified with -i: %s\n" ${OHITEM}
          ;;
        :)
          printf -- "Option -%s requires an argument. Exiting." ${OPTARG}
          exit 1
          ;;
        esac
done

# Check item
if [[ -z ${OHITEM} ]]
   then
      printf "No item specified. Exiting.\n"
      exit 1
fi

# Get URL
OHLOCALURL=$(cat ${OHLOCALURLFILE})

# Check authentication
if [[ -z "${OHAUTHSTR}" ]]
   then
      OHAUTHSTR=$(cat ${OHAUTHFILE} | grep ${OHUSER} | awk 'BEGIN { FS = "=" } ; { print $2 }')
      if [[ -z "${OHAUTHSTR}" ]]
         then
            USERSTR="-u ${OHUSER}"
         else
	    # Prevent the password to be displayed in test mode
            if [[ ${F_TEST} == TRUE ]]
               then
                  USERSTR="-u ${OHUSER}:******"
               else
                  OHAUTHSTR=${OHAUTHSTR%,*}
                  USERSTR="-u ${OHUSER}:${OHAUTHSTR}"
            fi
            OHAUTHSTR=""	# Contained password and not needed anymore
      fi
fi

# Compile execution command
if [[ -z ${OHCOMMAND} ]]
   then
      EXEC="curl ${INITOPTSTR} ${USERSTR} ${OHLOCALURL}/rest/items/${OHITEM}/state"
      POSTEXECSTR="\\n"
   else
      EXEC="curl -H \"${HEADERSTR}\" ${INITOPTSTR} ${USERSTR} -X POST -d \"${OHCOMMAND}\" ${OHLOCALURL}/rest/items/${OHITEM}"
      POSTEXECSTR=""
fi
unset USERSTR	# Contained password and not needed anymore


# Execute
if [[ ${F_TEST} == TRUE ]]
   then
      printf "Test mode. Command that would have been executed in normal mode:\n %s\n" "${EXEC}"
      EXITCODE=0
   else
      eval ${EXEC}
      EXITCODE=$?
      printf "${POSTEXECSTR}"
fi
unset EXEC		# Contained password and not needed anymore

exit ${EXITCODE}
