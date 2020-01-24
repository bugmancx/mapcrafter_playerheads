#!/bin/bash

# Update playerdata
/mnt/storage/minecraft/bin/mapcrafter/mirror_ftp.sh -p -c /mnt/storage/minecraft/bin/mapcrafter/conf/mirror_ftp.conf

# Regenerate player markers
/mnt/storage/minecraft/bin/mapcrafter/update_player_markers.sh -c /mnt/storage/minecraft/bin/mapcrafter/conf/zedcraft_smp_season3.conf
