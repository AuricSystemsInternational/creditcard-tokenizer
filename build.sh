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
MINIFY=true
#OPTIMIZE=
OPTIMIZE="--optimize"

TJS="elm-tokenizer.js"
MINTJS="elm-tokenizer.min.js"
DJS="elm-detokenizer.js"
MINDJS="elm-detokenizer.min.js"

DEBUG=
#DEBUG="--debug"
if ${BUILD_TOKENIZER}; then
elm.sh make src/tokenizer.elm ${DEBUG} ${OPTIMIZE} --output=$TJS
if ${MINIFY}; then
uglifyjs $TJS --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output=$MINTJS
fi
fi
if ${BUILD_DETOKENIZER}; then
elm.sh make src/detokenizer.elm ${DEBUG} --output=$DJS
if ${MINIFY}; then
uglifyjs $DJS --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output=$MINDJS

fi
fi


# elm format
# elm analyse
