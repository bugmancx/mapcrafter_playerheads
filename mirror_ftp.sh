#!/bin/bash

# Script to mirror the world from an FTP server
VERBOSE="--verbose=2"
GLOBS="--exclude crash-reports/ --exclude debug/ --exclude jar/ --exclude logs/ --exclude-glob *.zip --exclude-glob *.log --exclude entities.nbt.gz" # Except the globs
SRC_DIR="/"

# Defaults

usage()
{
    echo "usage: $0 -c server.conf [-p]"
    echo ""
    echo " -c : Path to configuration file"
    echo " -p : Mirror playerdata only"
    exit 1
}

while getopts "hpc:": arg; do
  case $arg in
    h)
      usage
      ;;
    p)
      SYNC="playerdata" # Specifying only playerdata files
      ;;
    c)
      config=$OPTARG # Path to configuration file
      ;;
  esac
done

# Check parameters
if [[ -z ${config} ]]
then
  echo "You need to specify a config file with -c ./config.conf"
  usage
  exit 1
else
  if [ ! -f "$config" ]; then
    echo "ERROR: $config file does not exist!"
    exit 2
  else
    source ${config} # All good - read the configuration file and set variables

    # Check variables are all in place.
    if [ -z "$SERVER" ]; then echo "ERROR: You haven't specified a SERVER configuration in ${config}." ; exit 2 ; fi
    if [ -z "$USERNAME" ]; then echo "ERROR: You haven't specified a USERNAME configuration in ${config}." ; exit 2 ; fi
    if [ -z "$PASSWORD" ]; then echo "ERROR: You haven't specified a PASSWORD configuration in ${config}." ; exit 2 ; fi
    if [ -z "$INSTANCEDIR" ]; then echo "ERROR: You haven't specified a INSTANCEDIR configuration in ${config}." ; exit 2 ; fi
    if [ -z "$WORLD" ]; then echo "ERROR: You haven't specified a WORLD configuration in ${config}." ; exit 2 ; fi

  fi
fi

########### Start working


# If Mapcrafter already running, quit. There's no point syncing again until the previous generation completes.
if pgrep -x "mapcrafter" > /dev/null
then
  exit 3
fi


# Check that world dir exists
if [ ! -d $INSTANCEDIR/$WORLD ] ; then
  mkdir -p $INSTANCEDIR/$WORLD
fi

if ! cd $INSTANCEDIR/$WORLD
then 
  echo "ERROR: $INSTANCEDIR/$WORLD doesn't exist"
  exit 2
fi

# Mirror the data

function mirror {
 lftp \
 	-u $USERNAME,$PASSWORD \
 	$SERVER \
        	-e "mirror --delete-first $GLOBS $VERBOSE $SRC_DIR $DST_DIR/ && exit" 
}


if [ "$SYNC" == "playerdata" ] ; then # Playerdata override was set
  SRC_DIR=/world/playerdata
  DST_DIR=$INSTANCEDIR/$WORLD

  mirror

else
  # Do lock routine - we only care about this if we are doing a full world mirror
  # Abort if lock exists
  if [ -f /tmp/mirror.$WORLD.lock ] ; then
    exit 3
  fi

  # Create a lock
  touch /tmp/mirror.$WORLD.lock

  # Sync everything
  DST_DIR=$INSTANCEDIR/$WORLD

  mirror

  # Remove lock
  rm -v /tmp/mirror.$WORLD.lock
fi

## Run Mapcrafter at this point

