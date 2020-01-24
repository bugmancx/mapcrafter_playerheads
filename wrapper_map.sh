#!/bin/bash

# Mirror world from FTP
/mnt/storage/minecraft/bin/mapcrafter/mirror_ftp.sh -c /mnt/storage/minecraft/bin/mapcrafter/conf/mirror_ftp.conf

# Update main map
/mnt/storage/minecraft/bin/mapcrafter/run_mapcrafter.sh -c /mnt/storage/minecraft/bin/mapcrafter/conf/mapcrafter/zedcraft_smp_season3.conf

# Update in-world markers
/mnt/storage/minecraft/bin/mapcrafter/run_mapcrafter_markers.sh -c /mnt/storage/minecraft/bin/mapcrafter/conf/mapcrafter/zedcraft_smp_season3.conf

