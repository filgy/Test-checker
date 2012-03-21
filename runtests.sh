#!/bin/bash

# IOS - Projekt
# Autor:
#
# find -type f  -print0 | xargs -0 ls -l
# find -type f -exec ls -l {} +

export LC_ALL=C

helpMessage="Usage: $0 [-vtrsc] TEST_DIR [regex]
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

function printError()
{
	if [ "$1" != "" ]; then
		echo "[!] $1" 1>&2
	fi
}

function processV()
{
	returnValue="$errorOK"
	
	if [ "$1" == "" ]; then
		printError "Undefined tree in function processV, skipping test"
		
		returnValue="$errorCore"
		return
	fi
	
	# start #main loop
	while read line; do		
		local dirCount=$((`find "$line" -maxdepth 1 -type d | wc -l` - 1))
		local fileCount=`find "$line" -maxdepth 1 \! -type d  | wc -l`	
		local softLinkCount=`find "$line" -maxdepth 1 -type l | wc -l`
		local hardLinkCount=`find "$line" -maxdepth 1 -type f -a \! -links 1 | wc -l`
		local extraFilesCount=`find "$line" -maxdepth 1 \! -type d ! -regex ".+\(\(stdout\|stderr\|status\)\-\(expected\|captured\|delta\)\|cmd\-given\|stdin\-given\)$" | wc -l`		
		
		echo "$line (D: $dirCount, F: $fileCount, E: $extraFilesCount)"
		
		# Pokud je v nejakem adresari aspon jeden adresar, tak v nem nejsou zadne jine soubory
		if [ "$dirCount" -gt 0 -a "$fileCount" -gt 0 ]; then
			printError "Directories and other files mixed in: $line"
			returnValue="$errorTest"
		fi
		
		# Ve stromu nejsou zadne symbolicke ani vicenasobne pevne odkazy
		if [ "$softLinkCount" -gt 0 -o "$hardLinkCount" -gt 0 ]; then
			printError "Hard or soft links in: $line"
			returnValue="$errorTest"
		fi
		
		# V kazdem adresari, ve kterem nejsou zadne dalsi adresare existuje soubor cmd-given a uzivatel ma pravo jej spoustet
		if [ "$dirCount" -eq 0 ] && [ ! -f "$line/cmd-given" -o ! -x "$line/cmd-given" ]; then
			printError "Cant find executable cmd-given in: $line"
			returnValue="$errorTest"
		fi
		
		# Vsechny soubory stdin-given jsou uzivateli pristupne pro cteni
		if [ -e "$line/stdin-given" -a ! -r "$line/stdin-given" ]; then
			printError "Found unreadable: $line/stdin-given"
			returnValue="$errorTest"
		fi				
		
		while read file; do
			# Vsechny soubory {stdout,stderr,status}-{expected,captured,delta} jsou uzivateli pristupne pro zapis, existuji-li
			if [ ! -w "$file" ]; then
				printError "Found unwritable: $file"
				returnValue="$errorTest"
			fi

			# Vsechny soubory status-{expected,captured} obsahuji pouze cele cislo zapsane v desitkove soustave nasledovane 0x0A
			if [ `basename "$file"` == "status-expected" -o `basename "$file"` == "status-captured"  ]; then
				if [ `cat "$file" | wc -l` -ne 1 ]; then
					printError "Extra line in: $file"
					returnValue="$errorTest"
				fi
			
				if [ `grep -xE "^[0-9]+$" "$file" | wc -l` -ne 1 ]; then
					printError "Not a number in: $file"
					returnValue="$errorTest"				
				fi
			fi
			
		done < <( find "$line" -maxdepth 1 -type f -regex ".+\(stdout\|stderr\|status\)\-\(expected\|captured\|delta\)$" )
		
		# Ve stromu jsou pouze adresare adresaru a vyse vyjmenovane soubory
		if [ "$extraFilesCount" -ne 0 ]; then
			printError "Found extra garbage in: $line"
			returnValue="$errorTest"
		fi
		

	done < <( find "$1" -type d | grep -E "$2" )
	# end of #main loop
	
	echo "$returnValue"
}

function processT(){
	return
}

function processR(){
	return
}

function processS(){
	returnValue="$errorOK"
	
	if [ "$1" == "" ]; then
		printError "Undefined tree in function processS, skipping test"
		
		returnValue="$errorCore"
		return
	fi
	
	while read line; do
		newName=`echo "$line" | sed -re  's/(stdout|stderr|status)\-captured/\1\-expected/g'`
	
		if [ -w "$line" ] && [ ! -e "$newName" -o -w "$newName" ]; then
			mv "$line" "$newName"
		else	
			printError "Cannot rename "$line", permission denied"
			returnValue="$errorTest"
		fi
	done < <( find "$1" -type f -regex ".+\(stdout\|stderr\|status\)\-captured$" | grep -E "$2" )
	
	echo "$returnValue"
}

function processC(){
	returnValue="$errorOK"
	
	if [ "$1" == "" ]; then
		printError "Undefined tree in function processC, skipping test"
		
		returnValue="$errorCore"
		return
	fi
	
	while read line; do

		if [ -w "$line" ]; then
			rm "$line"
		else
			printError "Cannot remove: $line"
			returnValue="$errorTest"
		fi

	done < <( find "$1" -type f -regex ".+\(stdout\|stderr\|status\)\-\(captured\|delta\)$" | grep -E "$2" )

	echo "$returnValue"
}

# Parsing arguments
while getopts ':vtrsc' argument; do

	case "$argument" in
		v)	argumentV=true;;
		t)	argumentT=true;;
		r)	argumentR=true;;
		s)	argumentS=true;;
		c)	argumentC=true;;
		*)
			printError "$helpMessage"
			exit $errorCore
		;;
	esac
done

# Required arguments count
argumentTotalCount="$#"
argumentCount=$(( $argumentTotalCount - $OPTIND ))

# Check count of required arguments
if [[ "$argumentCount" != 0 && "$argumentCount" != 1 || "$OPTIND" == 1  ]]; then
	echo "$helpMessage" 1>&2
	exit $errorCore
# Parsing arguments directory & regexp
elif [ "$argumentCount" == 1 ]; then
	eval argumentDir='$'$(( $argumentTotalCount - 1))
	eval argumentRegex='$'$(( $argumentTotalCount ))
# Parsing argument directory
elif [ "$argumentCount" == 0 ]; then
	eval argumentDir='$'$(( $argumentTotalCount ))
fi

# Checking valid tree
if [ ! -d "$argumentDir" ]; then
	printError "Invalid tree.. aborting!"
	exit $errorTest
fi

if $argumentV; then
	processV "$argumentDir" "$argumentRegex"
fi

if $argumentT; then
	processT "$argumentDir" "$argumentRegex"
fi

if $argumentR; then
	processR "$argumentDir" "$argumentRegex"
fi

if $argumentS; then
	processS "$argumentDir" "$argumentRegex"
fi

if $argumentC; then
	processC "$argumentDir" "$argumentRegex"
fi