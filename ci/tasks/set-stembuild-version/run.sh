#!/usr/bin/env bash
set -eu -o pipefail
set -x

RELEASE_VERSION=$( find stembuild-untested-linux -name stembuild-linux* -printf '%f' | cut -d '-' -f4 | cut -d '.' -f1-2 )
BIN_DIRS=( stembuild-untested-windows stembuild-untested-linux )

for DIR in "${BIN_DIRS[@]}"
do
    PLATFORM=$( echo ${DIR} | cut -d '-' -f3 )
    echo "*** Setting release version of ${PLATFORM} Stembuild ***"
    SOURCE_BINARY=$( find ${DIR} -name stembuild-\* -type f -printf "%f\n" )
    DEST_BINARY=$( echo ${SOURCE_BINARY} | sed -r 's/[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+(-build\.[[:digit:]]+)?/'${RELEASE_VERSION}'/g' )
    cp ${DIR}/${SOURCE_BINARY} final-stembuilds/${DEST_BINARY}
done

echo ${RELEASE_VERSION} > final-stembuilds/tag
