#!/bin/bash

# IOS - Projekt
# Autor:
#
#

export LC_ALL=C

helpMessage="Usage: $0 [-vtrsc] TEST_DIR [REGEX]
 -v validate tree
 -t run tests
 -r report results
 -s synchronize expected results
 -c clear generated files

It is mandatory to supply at least one option."

# Reset arguments
argumentV=false
argumentT=false
argumentR=false
argumentS=false
argumentC=false

# Define error codes
errorOK=0
errorTest=1
errorCore=2

# Parsing arguments
while getopts ':vtrsc' argument; do
	case "$argument" in
		v)	argumentV=true;;
		t)	argumentT=true;;
		r)	argumentR=true;;
		s)	argumentS=true;;
		c)	argumentC=true;;
		?)
			echo "$helpMessage" 1>&2
			exit $errorCore
		;;
	esac
done

# Check count of arguments
if [ "$#" == 0 ]; then
	echo "$helpMessage" 1>&2
	exit $errorCore
fi

if [ "$argumentV" == true ]; then
	echo "V"
fi

if [ "$argumentT" == true ]; then
	echo "T"
fi

if [ "$argumentR" == true ]; then
	echo "R"
fi

if [ "$argumentS" == true ]; then
	echo "S"
fi

if [ "$argumentC" == true ]; then
	echo "C"
fi
