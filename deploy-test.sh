#!/bin/bash
# Gather up the base code and the sample code for testing environments.

# Exit on first failure
set -o errexit

# Exit if using undeclared variable
set -o nounset

# Debug tracing
# set -o xtrace

rm -rf ./deploy
rm -f *tar.gz
mkdir -p deploy/css
mkdir -p deploy/js
mkdir -p deploy/images
mkdir -p deploy/sample-code

./build.sh

cp *.html deploy
cp *.js deploy
cp -R css/* deploy/css/
# cp -R js/* deploy/js/
cp -R images/ deploy/images/
cp -R sample-code/* deploy/sample-code

now=`date +"%Y-%m-%d"`
tar czvf "iframe-deploy-$now.tar.gz" deploy

