#!/bin/sh -e

BRAND=$(lspci | grep VGA | awk \{'print $5'\})
CODE=$(lspci | grep VGA | awk \{'print $7'\})
CODE="${CODE%M}"

getGPUGen(){
	if [ "$BRAND" = "NVIDIA" ]; then
		GPULIST="${ROOT_DIR}/src/gpufetch/gpulist"
		GEN="$(grep "$CODE" "$GPULIST")"
		if [ -n "$GEN" ]; then
			echo "$GEN"
		else
			echo "E2" # not in gpulist
		fi
	else
		echo "E1" # not a nvidia gpu
	fi
}

getDriver(){
	if [ "$GPU_GEN" -lt 6 ]; then
	:
	elif [ "$GPU_GEN" -eq 6 ]; then
		GPU_DRIVER="340xx"
	elif [ "$GPU_GEN" -eq 7 ]; then
		GPU_DRIVER="390xx"
	elif [ "$GPU_GEN" -eq 8 ]; then
		GPU_DRIVER="470xx"
	elif [ "$GPU_GEN" -gt 8 ] && [ "$GPU_GEN" -lt 14 ]; then
		GPU_DRIVER="580xx"
	elif [ "$GPU_GEN" -eq 14 ]; then
		GPU_DRIVER="open"
	fi

	if [ -n "$GPU_DRIVER" ]; then
		if [ "$GPU_DRIVER" = "open" ]; then
			echo "nvidia-open-dkms nvidia-utils lib32-nvidia-utils"
		else
			echo "nvidia-$GPU_DRIVER-dkms nvidia-$GPU_DRIVER-utils lib32-nvidia-$GPU_DRIVER-utils"
		fi
	fi
}


# backup from main file

# ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
# . "$ROOT_DIR/src/gpufetch/gpufetch.sh"

# Check GPU Driver
# GPU_GEN="$(getGPUGen | awk \{'print int($2)'\})"
# if [ -n "$GPU_GEN" ]; then
# 	GPU_DRIVER="$(getDriver)"
# fi
