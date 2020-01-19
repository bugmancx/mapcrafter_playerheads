#!/bin/bash

##
## update_player_markers.sh
## 
## Creates mapcrafter markers.js output files for player head icons on
## your mapcrafter map.
##
## REQUIREMENTS:
##
## This script requires the following to be installed on your server:
## 
## - nbt2yaml
## - ImageMagick (for convert)
## - mapcrafter_markers
## - wget
##
## 
## This script does several different things:
##
## ## EXTRACTING PLAYER DATA
## The script will process your Minecraft world's 'playerdata' directory and
## look for player files that have been updated within different timeframes.
## Depending on which timeframes it finds determines which "age" to apply
## to the player (online/offline/dormant/inactive.)
## 
## The script will process the player dat file and extract the player
## dimension. Depending on which dimension the player is currently in will
## determine which dimension template is used and they will show up in
## the correct dimension on the mapcrafter map.
##
## The script will determine the current coordinates of the player and
## this will be used to place their player head on the map.
##
## ## GENERATING PLAYER HEADS
## Player heads are 32x32 icons based on the player's skin.
##
## The script will check whether the player's head exists before fetching it
## for the first time.
##
## This script fetches player heads using the https://minotar.net/ API.
##
## If any player heads have not been updated for a certain timeframe, they
## will be automatically refetched via the API.
##
## Different textures are rendered in grayscale and transparency depending on
## whether a player is in different states -- online, offline, etc.
## 



set -e

usage()
{
    echo "usage: $0 -c server.conf [-v]"
    echo ""
    echo " -h : This help"
    echo " -c : Configuration File"
    echo " -v : Verbose Debugging"
    exit 1
}

while getopts "hvc:": arg; do
  case $arg in
    h)
      usage
      ;;
    v)
      DEBUG_MODE=1
      ;;
    c)
      CONFIG=$OPTARG # Path to configuration file
      ;;
  esac
done

# Check parameters
if [[ -z ${CONFIG} ]]
then
  echo "You need to specify a config file with -c ./config.conf"
  usage
  exit 1
else
  if [ ! -f "$CONFIG" ]; then
    echo "ERROR: $CONFIG file does not exist!"
    exit 2
  else
    source ${CONFIG} # All good - read the configuration file and set variables

    # Check if required variables are all in place.
    if [ -z "$INSTANCEDIR" ]; then echo "ERROR: You haven't specified a INSTANCEDIR configuration in ${CONFIG}." ; exit 2 ; fi
    if [ -z "$WORLD" ]; then echo "ERROR: You haven't specified a WORLD configuration in ${CONFIG}." ; exit 2 ; fi
    if [ -z "$OUTPUTDIR" ]; then echo "ERROR: You haven't specified a OUTPUTDIR configuration in ${CONFIG}." ; exit 2 ; fi
    if [ -z "$TEMPLATEDIR" ]; then echo "ERROR: You haven't specified a TEMPLATEDIR configuration in ${CONFIG}." ; exit 2 ; fi

  fi
fi

function print_debug {
if [[ $DEBUG_MODE == "1" ]]
then
#  [ $DEBUG_MODE -eq 1 ] && echo -ne "\033[00;35mDEBUG: $1" && echo -e '\033[0m'
  [ $DEBUG_MODE -eq 1 ] && echo -ne "\033[00;35mDEBUG: $1" && echo -e '\033[0m'
fi
}


nbt2yaml_path=~/.local/bin


tmp=/tmp/markers
finalcopy=$OUTPUTDIR/$WORLD/markers.js
uuidfile=$OUTPUTDIR/$WORLD/uuids.txt
playerdata_location="$INSTANCEDIR/$WORLD/world/playerdata" # Make this location easier to use

player_head_refresh_interval=2 # Days old
active_threshold=-5 # Minimum age of playerdata file required to qualify as online
inactive_threshold=-30 # Minimum age of playerdata file required to qualify as an active player (else does not show playerhead)

# Make sure world exists
if [ ! -d $INSTANCEDIR/$INSTANCE ] ; then
  echo "Error! Can't find $INSTANCEDIR/$INSTANCE"
  exit
fi

# Create the tmp dir
if [ ! -d $tmp ] ; then
  mkdir -p $tmp
else # Found a working directory. Need to clean it up.
  rm -rf $tmp/* 
fi

DATE=$(date)


############ FUNCTIONS ##############

## FUNCTION: Create a fuzzy date
hdate () {
  awk -v date="$(date -r $1 +%s)" -v now="$(date +%s)" '
    BEGIN {  diff = now - date;
       if (diff > (24*60*60)) printf "%.0f days ago", diff/(24*60*60);
       else if (diff > (60*60)) printf "%.0f hours ago", diff/(60*60);
       else if (diff > 60) printf "%.0f minutes ago", diff/60;
       else printf "%s seconds ago", diff;
    }'
}


## FUNCTION: Find players matching criteria
find_matching_players () {
  print_debug "FUNCTION CALLED: find_matching_players $1"

  if [ "$1" == "online" ] ; then
    find_criteria="-mmin -5" # Files are up to 5 minutes old
    dormancy="online"
  fi

  if [ "$1" == "offline" ] ; then
    find_criteria="-mmin +5 -mtime -7" # File is over 5 min but within 7 days old
    dormancy="offline"
  fi

  if [ "$1" == "dormant" ] ; then
    find_criteria="-mtime +7 -mtime -31" # File is over 7 days old but within 31 days old
    dormancy="dormant"
  fi

  if [ "$1" == "inactive" ] ; then
    find_criteria="-mtime +30" # File is over 30 days old
    dormancy="inactive"
  fi


  print_debug "Finding players matching dormancy $dormancy"

  # Clear variables
  player_files_array= # Clear variable
  player_files_sorted_array=

  player_files_array=$(/usr/bin/find $playerdata_location -type f $find_criteria)  # Find playerdata files within required timeframe
  print_debug "Running /usr/bin/find $playerdata_location -type f $find_criteria"
  print_debug "player_files_array = $player_files_array"

  if [ ! -z "$player_files_array" ] ; then # If we have player files to work with
    player_files_sorted_array=$(ls -t1 $player_files_array) # Sort playerdata files into array by last modified; newest first
    print_debug "We had player files found, and they were sorted"

  fi

  print_debug "Finished processing $dormancy - moving on to the next."
  print_debug "*******"


}

# FUNCTION: Get an avatar from remote server
get_avatar () {

  shrink_uuid $1 # Optimal UUID for API

  MASTER_AVATAR=$OUTPUTDIR/$WORLD/static/markers/$PLAYER_NAME.avatar.png
  wget -q "https://minotar.net/helm/$UUID_SHRUNK/32" --output-document=$MASTER_AVATAR # Get the player's head from this server
  sleep $((1 + RANDOM % 5)) # Don't harass the server in case we need to loop later
}

# FUNCTION: Generate different avatar images based on criteria
generate_avatars () {

MASTER_AVATAR=$OUTPUTDIR/$WORLD/static/markers/$PLAYER_NAME.avatar.png

  # Check if avatar exists
  if [ ! -e $MASTER_AVATAR ] ; then # if avatar does not exist
    get_avatar $UUID # get player avatar
  fi

  # Check if the avatar is older than a few days
  if [[ -n $(find $MASTER_AVATAR -mtime +$player_head_refresh_interval) ]] ; then # if avatar is older than $interval
    rm -v $OUTPUTDIR/$WORLD/static/markers/$PLAYER_NAME.*png # Since we are refreshing, move the variations so they will update next time as well
    get_avatar $UUID # refresh avatar
  fi

  # Create a converted avatar if we need to do so

  if [ "$1" == "online" ] ; then
    convert_criteria="" # Nothing; just copy this image. We do this in case we decide to make other criteria later
    dormancy="online"
  fi

  if [ "$1" == "offline" ] ; then
    convert_criteria="-colorspace Gray" # Make a grayscale image
    dormancy="offline"
  fi

  if [ "$1" == "dormant" ] ; then
    convert_criteria="-modulate 100,50,50" # Give the player head a pinkish hue
    dormancy="dormant"
  fi

  if [ "$1" == "dormant" ] ; then
    convert_criteria="-alpha set -channel A -evaluate Multiply 0.25 +channel" # Make the player head translucent
    dormancy="dormant"
  fi

  print_debug "Using dormancy $dormancy"


  # Check if avatar needs processing depending on player dormancy

  AVATAR_OUTPUT="$OUTPUTDIR/$WORLD/static/markers/$PLAYER_NAME.$dormancy.png" # Set working output file

  if [ ! -e $AVATAR_OUTPUT ] ; then # if avatar for this type does not exist
    convert $convert_criteria $MASTER_AVATAR $AVATAR_OUTPUT # generate avatar based on criteria
  fi

}


# FUNCTION: Shrink an expanded UUID
shrink_uuid () {
    UUID_SHRUNK=$(echo $1 | sed -e 's/\-//g')
}


# FUNCTION: Get PLAYER_NAME
get_player_name () {
print_debug "FUNCTION: get_player_name"
print_debug "Working with $player_file"
  # Get Player name
  PLAYER_NAME=$(grep "$UUID," $uuidfile | cut -d , -f 2)

  if [ -z $PLAYER_NAME ] ; then # Player name wasn't in uuids file, so need to get it from Mojang API
print_debug "No UUID match in $uuidfile. Getting from Mojang Session server"
    shrink_uuid $UUID
    PLAYER_NAME=$(curl -s https://sessionserver.mojang.com/session/minecraft/profile/${UUID_SHRUNK} | grep -v requests | cut -d : -f 3 | cut -d \" -f 2)
    echo $UUID,$PLAYER_NAME >> $uuidfile # Cache the player name
  fi
print_debug "Player Name Match: $PLAYER_NAME"


}

get_player_location () {
  LOCATION_RAW=$($nbt2yaml_path/nbt2yaml $player_file | grep -A3 "Pos: \!list_double" | tail -n 3 | cut -d \" -f 2 | sed -e 's/\..*//g' | tr '\n' ',' | sed -e 's/,$//g' | cut -d \. -f 1)

  X=$(echo $LOCATION_RAW | cut -d , -f 1)
  Y=$(echo $LOCATION_RAW | cut -d , -f 2)
  Z=$(echo $LOCATION_RAW | cut -d , -f 3)

  LOCATION=$(echo "$X,$Z,$Y") # Mapcrafter requires coordinates in X,Z,Y format, so rearrange these variables
}

log_location () {
  if [ ! -z {$LOGCOORDSDIR} ] ; then
    mkdir -p "/mnt/storage/minecraft/logs/instances/$INSTANCE/player_log/" # Create if doesnt exist, at least try to. We don't validate.
  fi

  echo "$DATE $PLAYER_NAME $DIMENSION $LOCATION" >> /mnt/storage/minecraft/logs/instances/$INSTANCE/player_log/$PLAYER_NAME.log

}

get_player_dimension () {
  # Work out the player dimension to display them on the correct map
  DIMENSION_RAW=$($nbt2yaml_path/nbt2yaml $player_file | grep "Dimension:" | awk '{ print $3 }')

  if [ "$DIMENSION_RAW" == "-1" ] ; then # Player is in the nether
    DIMSUFFIX="_nether"
    TEMPLATE="nether"
  fi

  if [ "$DIMENSION_RAW" == "0" ] ; then # Player is in the overworld
    DIMSUFFIX=""
    TEMPLATE="overworld"
  fi

  if [ "$DIMENSION_RAW" == "1" ] ; then # Player is in the end
    DIMSUFFIX="_end"
    TEMPLATE="end"
  fi

  DIMENSION="$WORLD$DIMSUFFIX" # Set variables for markers template

  print_debug "Found $PLAYER_NAME in $DIMENSION_RAW which is $DIMSUFFIX ($TEMPLATE)"

}

generate_template_data () {

print_debug "FUNCTION CALLED - generate_template_data $1"

for player_file in $player_files_sorted_array ; do
print_debug "START: Processing $player_file"
  UUID=$(basename $player_file | sed -e 's/\.dat//g')

  get_player_name
  get_player_location
  get_player_dimension

  generate_avatars $dormancy

print_debug "Working with $player_file as UUID $UUID"
print_debug "Putting $PLAYER_NAME in $DIMENSION which outputs to $tmp/markers.data.$DIMENSION.$dormancy.js"

  if [ "$dormancy" != "online" ] ; then # Player is offline
    # Only add player age metadata if the player is offline
    playerfile_age_output=" (Last seen $(hdate $player_file))"
  fi

  cat $TEMPLATEDIR/markers.group.data.js | sed -e "s/ICON/${PLAYER_NAME}.${dormancy}.png/g" | sed -e "s/LOCATION/${LOCATION}/g" | sed -e "s/PLAYER/${PLAYER_NAME}/g" | sed -e "s/TEXT/${PLAYER_NAME}${playerfile_age_output}/g" >> "$tmp/markers.data.$DIMENSION.$dormancy.js"

# Dump output on stdout
  cat $TEMPLATEDIR/markers.group.data.js | sed -e "s/ICON/${PLAYER_NAME}.${dormancy}.png/g" | sed -e "s/LOCATION/${LOCATION}/g" | sed -e "s/PLAYER/${PLAYER_NAME}/g" | sed -e "s/TEXT/${PLAYER_NAME}${playerfile_age_output}/g"

print_debug "STOP: Finished processing $player_file"
print_debug "*********************************************"

if [[ $DEBUG_MODE -eq 1 ]] ; then
  print_debug "Having a little sleep between players..."
  sleep 3
fi

done

}


assemble_template () {

dormancy=$1
show=$2

overworldsuffix="" # Overworld has no suffix. Rather annoying
endsuffix="_end"
nethersuffix="_nether"

dimmaps="$WORLD$overworldsuffix $WORLD$endsuffix $WORLD$nethersuffix" # Hack the variables for a loop. Yuck.


# make markers

# Start the section header
    cat $TEMPLATEDIR/markers.group.header.js | sed -e "s/ID/${dormancy}/g"| sed -e "s/DORMANCY/${dormancy}/g" | sed -e "s/DIMMAP/$group/g" | sed -e "s/SHOW/$show/g" >> $markersjs_output
print_debug "cat $TEMPLATEDIR/markers.group.header.js | sed -e "s/ID/${dormancy}/g"| sed -e "s/DORMANCY/${dormancy}/g" | sed -e "s/DIMMAP/$group/g" >> $markersjs_output"
print_debug "Added $TEMPLATEDIR/markers.group.header.js with ID ${dormancy}, DORMANCY ${dormancy}, DIMMAP ${group}"

#### LOOP PER DIMENSION
print_debug "DIMENSION LOOP: Looping through $dimmaps"
    for group in $dimmaps ; do

print_debug "DIMENSION LOOP: Generating markers content for with dimension $group.$dormancy"
      if [ -f $tmp/markers.data.$group.$dormancy.js ] ; then

      # Create markers map subsection
        cat $TEMPLATEDIR/markers.group.dimension.header.js | sed -e "s/DIMMAP/$group/g" >> $markersjs_output
print_debug "Added $TEMPLATEDIR/markers.group.dimension.header.js with DIMMAP ${group}"

      # Add in all of the player lines
        cat $tmp/markers.data.$group.$dormancy.js >> $markersjs_output

      # Add in the "markers" footer
        cat $TEMPLATEDIR/markers.group.dimension.footer.js >> $markersjs_output

      else
        # Nothing to do
print_debug "SKIPPING: Couldn't find $tmp/markers.data.$group.$dormancy.js"
      fi

  done

      # Close out the section
    cat $TEMPLATEDIR/markers.group.footer.js >> $markersjs_output

}


## Define template files


#### CREATE TEMPLATES FOR LATER MERGING

find_matching_players "online"
log_location
generate_template_data

find_matching_players "offline"
generate_template_data

find_matching_players "dormant"
generate_template_data

find_matching_players "inactive"
generate_template_data


## ASSEMBLE FILES

markersjs_output=$tmp/markers.js

# Initialise file header bits
echo "// Generated on $(date)" > $markersjs_output
cat $TEMPLATEDIR/markers.header.js >> $markersjs_output

# Assemble content subsections

assemble_template online true
assemble_template offline false
assemble_template dormant false
assemble_template inactive false

# Add footer
cat $TEMPLATEDIR/markers.footer.js >> $markersjs_output

print_debug "$markersjs_output assembly complete!"


print_debug "$(cat $markersjs_output)"


# Move into place
mv -v $markersjs_output $finalcopy
rm -rf $tmp # Clean up working dir

