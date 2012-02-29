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

argumentDir=""
argumentRegex=""

# Define error codes
errorOK=0
errorTest=1
errorCore=2

# Test parsing
#while [ "$#" != 0 ]; do
#	echo "$@"
#	shift
#	sleep 1
#done
#
#exit 0
#
# Check count of arguments <2,3>
#if [[ $# -lt 2 || $# -gt 3 ]]; then
	#echo "$helpMessage" 1>&2
	#exit $errorCore
#fi

# Parsing arguments
while getopts ':vtrsc' argument; do

	case "$argument" in
		v)	argumentV=true;;
		t)	argumentT=true;;
		r)	argumentR=true;;
		s)	argumentS=true;;
		c)	argumentC=true;;
		*)
			echo "$helpMessage" 1>&2
			exit $errorCore
		;;
	esac
done

# Required arguments count
argumentTotalCount="$#"
argumentCount=$(( $argumentTotalCount - $OPTIND ))

# Check count of required arguments
if [[ "$argumentCount" != 0 && "$argumentCount" != 1  ]]; then
	echo "$helpMessage" 1>&2
	exit $errorCore
#
elif [ "$argumentCount" == 1 ]; then
	eval argumentDir='$'$(( $argumentTotalCount - 1))
	eval argumentRegex='$'$(( $argumentTotalCount ))
#
elif [ "$argumentCount" == 0 ]; then
	eval argumentDir='$'$(( $argumentTotalCount ))
fi

echo -n "Functions: "

if $argumentV; then
	echo -n "V"
fi

if $argumentT; then
	echo -n "T"
fi

if $argumentR; then
	echo -n"R"
fi

if $argumentS; then
	echo -n "S"
fi

if $argumentC; then
	echo -n "C"
fi

echo ""

# Debug output
echo "Argument directory: $argumentDir"
echo "Argument regex: $argumentRegex"
