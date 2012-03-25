#!/bin/bash

# IOS - Projekt 1
# Autor: F. Kolacek xkolac12
#
# jednotlive adresa sort dle absolutni cesty

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

colorOk="\033[32m""OK""\033[0m"
colorFailed="\033[31m""FAILED""\033[0m"

function printError()
{
	if [ "$1" != "" ]; then
		echo "[!] $1" 1>&2
	fi
}

function printStatus()
{

        if [ "$1" != "" ]; then
                if [ -t "$3" ];then
                        case "$2" in
                                0) echo -e "$1: $colorOk" 1>&"$3";;
                                *) echo -e "$1: $colorFailed" 1>&"$3";
                        esac
                else
                        case "$2" in
                                0) echo "$1: OK" 1>&"$3";;
                                *) echo "$1: FAILED" 1>&"$3";
                        esac
                fi
        fi
}

function processV()
{
	if [ "$1" == "" ]; then
		printError "Undefined tree in function processV, skipping test"
		
		return "$errorCore"		
	fi
	
	# start #main loop
	while read line; do		
		local dirCount=$((`find "$line" -maxdepth 1 -type d | wc -l | sed -re 's/\ //g'` - 1))
		local fileCount=`find "$line" -maxdepth 1 \! -type d  | wc -l | sed -re 's/\ //g'`	
		local softLinkCount=`find "$line" -maxdepth 1 -type l | wc -l | sed -re 's/\ //g'`
		local hardLinkCount=`find "$line" -maxdepth 1 -type f -a \! -links 1 | wc -l | sed -re 's/\ //g'`
		#local extraFilesCount=`find "$line" -maxdepth 1 \! -type d ! -regex ".+\(\(stdout\|stderr\|status\)\-\(expected\|captured\|delta\)\|cmd\-given\|stdin\-given\)$" | wc -l`		
		local extraFilesCount=`find "$line" -maxdepth 1 \! -type d | grep -v -E "((stdout|stderr|status)\-(expected|captured|delta)|cmd\-given|stdin\-given)$" | wc -l | sed -re 's/\ //g'`		
		
		#printStatus "$line (D: $dirCount, F: $fileCount, E: $extraFilesCount)" 1
		
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
			printError "No executable cmd-given in: $line"
			returnValue="$errorTest"
		fi
		
		# Vsechny soubory stdin-given jsou uzivateli pristupne pro cteni
		if [ -e "$line/stdin-given" -a ! -r "$line/stdin-given" ]; then
			printError "No read permissions in: $line/stdin-given"
			returnValue="$errorTest"
		fi				
		
		while read file; do
			# Vsechny soubory {stdout,stderr,status}-{expected,captured,delta} jsou uzivateli pristupne pro zapis, existuji-li
			if [ ! -w "$file" ]; then
				printError "No write permissions in: $file"
				returnValue="$errorTest"
			fi

			# Vsechny soubory status-{expected,captured} obsahuji pouze cele cislo zapsane v desitkove soustave nasledovane 0x0A
			if [ `basename "$file"` == "status-expected" -o `basename "$file"` == "status-captured"  ]; then
				if [ `cat "$file" | wc -l | sed -re 's/\ //g'` -ne 1 ]; then
					printError "Extra line in: $file"
					returnValue="$errorTest"
				fi
			
				if [ `grep -xE "^[0-9]+$" "$file" | wc -l | sed -re 's/\ //g'` -ne 1 ]; then
					printError "Not a number in: $file"
					returnValue="$errorTest"				
				fi
			fi
			
		# done < <( find "$line" -maxdepth 1 -type f -regex ".+\(stdout\|stderr\|status\)\-\(expected\|captured\|delta\)$" )		
		done < <( find "$line" -maxdepth 1 -type f | grep -E "(stdout|stderr|status)\-(expected|captured|delta)$" )
		
		# Ve stromu jsou pouze adresare adresaru a vyse vyjmenovane soubory
		if [ "$extraFilesCount" -ne 0 ]; then
			printError "Unexpected files in: $line"
			returnValue="$errorTest"
		fi
		

	done < <( find "$1" -type d | grep -E "$2" | sort )
	# end of #main loop
	
	return "$returnValue"
}

function processT(){
	local returnValue="$errorOK"
	local testValue=0
	
	local currentDir=`pwd`

	# start of #main loop
	while read line; do
		if [ -e "$line/cmd-given" ]; then

			testValue=0
			cd "$line"
			if [ "$?" -ne 0 ]; then
				printError "Cannot enter to: $line"
				returnValue=1; 
				continue
			fi

			if [ -e "stdin-given" ]; then
				./cmd-given < stdin-given 1> stdout-captured 2> stderr-captured
				echo "$?" > status-captured
			else
				./cmd-given < /dev/null 1> stdout-captured 2> stderr-captured
				echo "$?" > status-captured
			fi		
			
			diff -up stdout-expected stdout-captured > stdout-delta 
			if [ "$?" -gt 1 ]; then
				#testValue=1; 
				returnValue=1; 
			fi
			
			diff -up stderr-expected stderr-captured > stderr-delta
			if [ "$?" -gt 1 ]; then 
				#testValue=1; 
				returnValue=1; 
			fi
			
			diff -up status-expected status-captured > status-delta
			if [ "$?" -gt 1 ]; then 
				#testValue=1; 
				returnValue=1; 
			fi
			
			if [ -s "stdout-delta" -o -s "stderr-delta" -o -s "status-delta" ]; then
				testValue=1
				returnValue=1
			fi

			canonPath=`echo "${line/$1//}" | sed -re 's/^\/+//g'`
			#printStatusStderr "$canonPath" "$testValue"
			printStatus "$canonPath" "$testValue" "2"
			
			cd "$currentDir"
			if [ "$?" -ne 0 ]; then
				printError "Cannot return to: $currentDir, aborting test"
				returnValue=1; 
				break
			fi
			
		fi	
	done < <( find "$1" -type d |  grep -E "$2" | sort )
	#end of #main loop	

	return "$returnValue"
}

function processR(){
	local returnValue="$errorOK"
	local testValue=0
	
	local currentDir=`pwd`

	# start of #main loop
	while read line; do
	
		if [ -e "$line/cmd-given" ]; then
		
			testValue=0
			cd "$line"
			
			if [ "$?" -ne 0 ]; then
				printError "Cannot enter to: $line"
				returnValue=1; 
				continue
			fi
		
			diff -up stdout-expected stdout-captured > stdout-delta 
			if [ "$?" -gt 1 ]; then
				#testValue=1; 
				returnValue=1; 
			fi
			
			diff -up stderr-expected stderr-captured > stderr-delta
			if [ "$?" -gt 1 ]; then 
				#testValue=1; 
				returnValue=1; 
			fi
			
			diff -up status-expected status-captured > status-delta
			if [ "$?" -gt 1 ]; then 
				#testValue=1; 
				returnValue=1; 
			fi
			
			if [ -s "stdout-delta" -o -s "stderr-delta" -o -s "status-delta" ]; then
				testValue=1
				returnValue=1
			fi

			canonPath=`echo "${line/$1//}" | sed -re 's/^\/+//g'`
			#printStatusStdout "$canonPath" "$testValue"
			printStatus "$canonPath" "$testValue" "1"
			
			cd "$currentDir"	

			if [ "$?" -ne 0 ]; then
				printError "Cannot return to: $currentDir, aborting test"
				returnValue=1; 
				break
			fi
		fi
	
	done < <( find "$1" -type d |  grep -E "$2" | sort )
	#end of #main loop	
	
	return "$returnValue"
}

function processS(){
	local returnValue="$errorOK"
	
	if [ "$1" == "" ]; then
		printError "Undefined tree in function processS, skipping test"
		
		return "$errorCore"
	fi
	
	while read line; do
		newName=`echo "$line" | sed -re  's/(stdout|stderr|status)\-captured/\1\-expected/g'`
	
		if [ -w "$line" ] && [ ! -e "$newName" -o -w "$newName" ]; then
			mv "$line" "$newName"
		else	
			printError "Cannot rename file: $line"
			returnValue="$errorTest"
		fi
	# done < <( find "$1" -type f -regex ".+\(stdout\|stderr\|status\)\-captured$" | sort | grep -E "$2" )
	done < <( find "$1" -type f | grep -E "(stdout|stderr|status)\-captured$" |  grep -E "$2" | sort )
	
	return "$returnValue"
}

function processC(){
	local returnValue="$errorOK"
	
	if [ "$1" == "" ]; then
		printError "Undefined tree in function processC, skipping test"
		
		return "$errorCore"
	fi
	
	while read line; do

		if [ -w "$line" ]; then
			rm "$line"
		else
			printError "Cannot remove file: $line"
			returnValue="$errorTest"
		fi

	# done < <( find "$1" -type f -regex ".+\(stdout\|stderr\|status\)\-\(captured\|delta\)$" | sort | grep -E "$2" )	
	done < <( find "$1" -type f | grep -E "(stdout|stderr-status)\-(captured|delta)$" |  grep -E "$2" | sort )

	return "$returnValue"
}

returnValue="$errorOK"

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
	printError "$helpMessage"
	exit "$errorCore"
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
	exit "$errorCore"
fi

if $argumentV; then
	processV "$argumentDir" "$argumentRegex"
	returnValue=$(( $returnValue + $?))
fi

if $argumentT; then
	processT "$argumentDir" "$argumentRegex"	
	returnValue=$(( $returnValue + $?))
fi

if $argumentR; then
	processR "$argumentDir" "$argumentRegex"	
	returnValue=$(( $returnValue + $?))
fi

if $argumentS; then
	processS "$argumentDir" "$argumentRegex"
	returnValue=$(( $returnValue + $?))
fi

if $argumentC; then
	processC "$argumentDir" "$argumentRegex"
	returnValue=$(( $returnValue + $?))
fi

if [ "$returnValue" -gt 0 ]; then
	exit "$errorTest"
else
	exit "$errorOK"
fi