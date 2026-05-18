#!/bin/sh

BRAND=$(lspci | grep VGA | awk {'print $5'})
echo $BRAND
CODE=$(lspci | grep VGA | awk {'print $7'})
echo $CODE

if [ $BRAND == "NVIDIA" ]; then
	while read line; do	
		CODES=$(echo $line | grep "^[^#]")

		CURRENT_CODE=$(echo "$CODES" | awk '{print $1}')
		if [ -n "$CODES" ] && [ -n "$(echo "$CODE" | grep "$CURRENT_CODE")" ]; then	
			MATCH=$CODES
			break
		fi
	done < ./gpulist
	echo $MATCH
fi