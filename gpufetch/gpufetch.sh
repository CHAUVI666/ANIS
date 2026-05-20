#!/bin/sh

BRAND=$(lspci | grep VGA | awk \{'print $5'\})
CODE=$(lspci | grep VGA | awk \{'print $7'\})
CODE="${CODE%M}"

getGPUGen(){
	if [ "$BRAND" = "NVIDIA" ]; then
		GPULIST="${ROOT_DIR}/gpufetch/gpulist"
		GEN="$(grep "$CODE" "$GPULIST")"
		echo "$GEN"
		if [ -n "$GEN" ]; then
			echo "$GEN"
		else
			echo "E2"
		fi
	else
		echo "E1"
	fi
}