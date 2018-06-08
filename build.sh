#!/bin/bash
# Build the iFrames.

# Exit on first failure
set -o errexit

# Exit if using undeclared variable
set -o nounset

# Debug tracing
# set -o xtrace

BUILD_DETOKENIZER=true
BUILD_TOKENIZER=true
MINIFY=false
DEBUG=
#DEBUG="--debug"
if ${BUILD_TOKENIZER}; then
elm make src/tokenizer.elm ${DEBUG} --warn --output elm-tokenizer.js
if ${MINIFY}; then
minify elm-tokenizer.js --clean --template={{filename}}-{{md5}}.min.{{ext}}
fi
fi
if ${BUILD_DETOKENIZER}; then
elm make src/detokenizer.elm ${DEBUG} --warn --output elm-detokenizer.js
if ${MINIFY}; then
minify elm-detokenizer.js --template={{filename}}-{{md5}}.min.{{ext}}
fi
fi


# elm format
# elm analyse
