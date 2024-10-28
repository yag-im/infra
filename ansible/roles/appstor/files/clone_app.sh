#!/usr/bin/env bash

set -eu

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 USER_ID APP_SLUG APP_RELEASE_UUID"
    exit 1
fi

USER_ID=$1
APP_SLUG=$2
APP_RELEASE_UUID=$3
MOUNT_ROOT=/opt/yag/data/appstor

# SRC_PATH: /opt/yag/data/appstor/apps/the-pink-panther-hokus-pokus-pink/780a21c5-5635-4a6d-aece-c9267b4ac8ff
# DST_PATH: /opt/yag/data/appstor/clones/0/the-pink-panther-hokus-pokus-pink
SRC_PATH=$MOUNT_ROOT/apps/$APP_SLUG/$APP_RELEASE_UUID
DST_PATH=$MOUNT_ROOT/clones/$USER_ID/$APP_SLUG

if [ ! -d $SRC_PATH ]; then
    echo "source path $SRC_PATH doesn't exist"
    exit 1
fi

if [ ! -d $DST_PATH ]; then
    mkdir -p $DST_PATH    
fi

if [ ! -d $DST_PATH/$APP_RELEASE_UUID ]; then
    echo "cp -r --reflink=always $SRC_PATH $DST_PATH"
    cp -r --reflink=always $SRC_PATH $DST_PATH
fi

exit 0
