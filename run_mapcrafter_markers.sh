#!/bin/bash

#MAPCRAFTER_MARKERS=/home/minecraft/git/_minecraft/_mapcrafter/115/mapcrafter/src/mapcrafter_markers
MAPCRAFTER_MARKERS=/home/minecraft/git/_minecraft/_mapcrafter/mapcrafter/src/mapcrafter_markers

##

set -e

usage()
{
    echo "usage: $0 -w world"
    echo ""
    echo " -h : This help"
    echo " -c : Path to Mapcrafter config"
    echo " -v : Verbose mode"
    exit 1
}

while getopts "hvc:": arg; do
  case $arg in
    h)
      usage
      ;;
    v)
      VERBOSE="-v"
      ;;
    c)
      CONFIG=${OPTARG}
      ;;
  esac
done

# Check parameters
if [[ -z ${CONFIG} ]]
then
  echo "You need to specify a Mapcrafter configuration file"
  echo
  usage
  exit 1
else
  if [ ! -f "$CONFIG" ]; then
    echo "ERROR: $CONFIG file does not exist!"
    exit 2
  fi
fi

function print_debug {
if [[ $DEBUG_MODE == "1" ]]
then
#  [ $DEBUG_MODE -eq 1 ] && echo -ne "\033[00;35mDEBUG: $1" && echo -e '\033[0m'
  [ $DEBUG_MODE -eq 1 ] && echo -ne "\033[00;35mDEBUG: $1" && echo -e '\033[0m'
fi
}

# Run it
$MAPCRAFTER_MARKERS $VERBOSE -c $CONFIG
#$($MAPCRAFTER_MARKERS $VERBOSE -c $CONFIG)
