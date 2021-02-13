#!/bin/bash
##
## /usr/local/script/slimgc.sh
## Image conversion script to create svg-logos from png-images
## using Imagick and Potrace
##
## Created on 08 MAR 2015
## Version 1.0 dated 08 MAR 2015
##
## Arguments
##  -s <file> : source file
##  -c <file> : file to be created
##  -b : use background colour
##  -i : invert image
##  -v : verbose
##  -h : displays usage
##

# Set variables and default values
set -u
IMAGCMD="convert"           # Use ImageMagick to create bitmap
IMAGOPT="-background white" # Convert options for creating bitmap
IMAGOPTPRE=""               # Convert options to apply on input file; only for reverse
IMAGOPTPOST=""              # Convert options to apply on output file; only for reverse
IMAGEXEC=""                 # String for the compiled convert execute command
POTRACECMD="potrace"        # Use Potrace to create svg
POTRACEOPT="-s"             # Potrace options
POTRACEEXEC=""              # String for the compiled potrace execute command
FILE_SOURCE=""              # Image to be converted
FILE_CREATE=""              # Image to be created
FILE_BITMAP=""              # Temporary bitmap file
F_VERBOSE=""                # Verbose flag
F_BACKGROUND=""             # Background flag; use secondary colour as background.
F_INVERT=""                 # Invert imagea.
F_REVERSE=""                # Reverse flag; make png-image from svg-logo
IMG_C_PRIMARY="#FFFFFF"     # Primary colour for transparent background; transparent by default
IMG_C_SECONDARY="#195594"   # Secondary colour, used for backgrounds; transparent by default
IMG_C_INVERTED="#111111"    # Reverse colour, used for inverted images w/ white backgrounds
IMG_WIDTH="255"             # Standard image width

# Check if commands are available
if [[ ! -x $(which ${IMAGCMD}) ]]; then
    printf "Cannot find command '%s'. Exiting.\n" ${IMAGCMD}
    exit 1
fi
if [[ ! -x $(which ${POTRACECMD}) ]]; then
    printf "Cannot find command '%s'. Exiting.\n" ${POTRACECMD}
    exit 1
fi

# Evaluate options
while getopts "s:c:w:ribvh" opt; do
    case "$opt" in
        \? | h)
            printf -- "Usage: %s \n  -s <filename> : source image\n  -c <filename> : svg-file to be created\n  [-w <pts>] : set the standard width of the image\n  [-b] : use background colour\n  [-i] : invert image\n  [-r] : reverse, i.e. create png from svg\n  [-v] : verbose mode\n  [-h] : show usage\n" ${0##*/}
            exit 2
        ;;
        v)
            F_VERBOSE=TRUE
            #printf -- "Verbose mode: script will print executed commands.\n"
        ;;
        s)
            FILE_SOURCE=${OPTARG}
            #printf -- "File specified with -s: %s\n" ${FILE_SOURCE}
        ;;
        c)
            FILE_CREATE=${OPTARG}
            #printf -- "File to be created specified with -c: %s\n" ${FILE_CREATE}
        ;;
        r)
            F_REVERSE=TRUE
            #printf -- "Reverse mode: png-image will be created from svg-file.\n"
        ;;
        w)
            IMG_WIDTH=${OPTARG}
            #printf -- "Image width specified with -w: %s\n" ${IMGWIDT}
        ;;
        i)
            F_INVERT=TRUE
            #printf -- "-i option used: image will be inverted.\n"
        ;;
        b)
            F_BACKGROUND=TRUE
            #printf -- "-b option used: image will have coloured background.\n"
        ;;
        :)
            printf -- "Option -%s requires an argument. Exiting." ${OPTARG}
            exit 1
        ;;
    esac
done

if [[ ! -e ${FILE_SOURCE} ]]
then
    printf "Source file does not exist or not specified. Exiting.\n"
    exit 1
fi

if [[ -z ${FILE_CREATE} ]]
then
    printf "No file to be created specified. Exiting.\n"
    exit 1
fi

if [[ ! ${F_REVERSE} == TRUE ]]
then
    
    ### 1. CRTEATE BITMAP
    
    # Compile options and command
    FILE_BITMAP="${FILE_SOURCE}.ppm"
    IMAGEXEC="${IMAGCMD} ${FILE_SOURCE} ${IMAGOPT} ${FILE_BITMAP}"
    
    # Execute command
    if [[ ${F_VERBOSE} == TRUE ]]
    then
        printf "Executing: %s ..." "${IMAGEXEC}"
    fi
    eval ${IMAGEXEC}
    EXITCODE=${?}
    
    # Check for errors
    if [[ ! ${EXITCODE} == 0 ]]
    then
        if [[ ${F_VERBOSE} == TRUE ]]
        then
            printf "ERROR.\nNew image not created.\n"
        else
            printf "Error executing:\n %s\nNew image not created.\n" "${IMAGEXEC}"
        fi
        exit ${EXITCODE}
    else
        if [[ ${F_VERBOSE} == TRUE ]]
        then
            printf "done.\n"
        fi
    fi
    
    ### 2. CREATE SVG IMAGE
    
    # Compile options and command
    if [[ ${F_INVERT} == TRUE ]]
    then
        if [[ ${F_BACKGROUND} == TRUE ]]
        then
            POTRACEOPT="${POTRACEOPT} -i --color \"${IMG_C_PRIMARY}\" --fillcolor \"${IMG_C_INVERTED}\""
        else
            POTRACEOPT="${POTRACEOPT} --color \"${IMG_C_INVERTED}\""
        fi
    else
        if [[ ${F_BACKGROUND} == TRUE ]]
        then
            POTRACEOPT="${POTRACEOPT} -i --color \"${IMG_C_SECONDARY}\" --fillcolor \"${IMG_C_PRIMARY}\""
        else
            POTRACEOPT="${POTRACEOPT} --color \"${IMG_C_PRIMARY}\""
        fi
    fi
    POTRACEOPT="${POTRACEOPT} -W ${IMG_WIDTH}pt"
    POTRACEEXEC="${POTRACECMD} -o ${FILE_CREATE} ${POTRACEOPT} ${FILE_BITMAP}"
    
    # Execute command
    if [[ ${F_VERBOSE} == TRUE ]]
    then
        printf "Executing: %s ..." "${POTRACEEXEC}"
    fi
    eval ${POTRACEEXEC}
    EXITCODE=${?}
    
    # Check for errors
    if [[ ! ${EXITCODE} == 0 ]]
    then
        if [[ ${F_VERBOSE} == TRUE ]]
        then
            printf "ERROR.\nNew image not created.\n"
        else
            printf "Error executing:\n %s\nNew image not created.\n" "${POTRACEEXEC}"
        fi
        exit ${EXITCODE}
    else
        if [[ ${F_VERBOSE} == TRUE ]]
        then
            printf "done.\n"
        fi
    fi
    
    # Remove bitmap image file
    if [[ -e ${FILE_BITMAP} ]]
    then
        rm ${FILE_BITMAP}
    fi
    exit 0
    
else
    
    ### 3. REVERSE: CREATE PNG FROM SVG
    
    # Compile options and command
    if [[ ${F_INVERT} == TRUE ]]
    then
        if [[ ${F_BACKGROUND} == TRUE ]]
        then
            IMAGOPTPRE="${IMAGOPTPRE} -background \"${IMG_C_SECONDARY}\""
        else
            IMAGOPTPRE="${IMAGOPTPRE} -negate"
        fi
    else
        if [[ ${F_BACKGROUND} == TRUE ]]
        then
            IMAGOPTPRE="${IMAGOPTPRE} -background \"${IMG_C_PRIMARY}\""
        else
            IMAGOPTPRE="${IMAGOPTPRE} -transparent \"${IMG_C_PRIMARY}\""
        fi
    fi
    IMAGEXEC="${IMAGCMD} ${IMAGOPTPRE} ${FILE_SOURCE} ${IMAGOPTPOST} ${FILE_CREATE}"
    
    # Execute command
    if [[ ${F_VERBOSE} == TRUE ]]
    then
        printf "Executing: %s ..." "${IMAGEXEC}"
    fi
    eval ${IMAGEXEC}
    EXITCODE=${?}
    
    # Check for errors
    if [[ ! ${EXITCODE} == 0 ]]
    then
        if [[ ${F_VERBOSE} == TRUE ]]
        then
            printf "ERROR.\nNew image not created.\n"
        else
            printf "Error executing:\n %s\nNew image not created.\n" "${IMAGEXEC}"
        fi
        exit ${EXITCODE}
    else
        if [[ ${F_VERBOSE} == TRUE ]]
        then
            printf "done.\n"
        fi
    fi
    exit 0
    
fi
# We should never end up here
exit -1
