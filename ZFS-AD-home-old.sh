#!/bin/bash

set -Eeuo pipefail

# Define values for Active Directory, folder and ZFS names
ADHOMEDATASET="AD-home"
ADHOMEPOOL="tank"
ADHOMEDIR="/mnt/${ADHOMEPOOL}/${ADHOMEDATASET}"
ADDOMAINNAME="AD"

# Set internal field separator for array to newline with $ escape to avoid issues with spaces and bash array.c's array_to_string_internal()
IFS=$'\n'

# Create arrays with existing AD usernames that have folders, and usernames that have ZFS datasets
mapfile -t zfsHomeDirs < <(zfs list | grep ${ADHOMEDATASET} | awk '//{print $1}' | awk -F"\/" '//{print $3}' 2>/dev/null | awk NF)
mapfile -t folderHomeDirs < <(find ${ADHOMEDIR} -maxdepth 1 -type d | sed 's/\.\///g' | grep -vF "." | awk -F"\/" '//{print $5}' 2>/dev/null | awk NF)

echo && echo -e "\e[4mDoes ZFS dataset exist for folder name?\e[0m"
# For each username folder, if no ZFS dataset exists for username, create dataset
for folder in "${folderHomeDirs[@]}"; do
	echo "\e[1m${folder}\e[0m" # debugging
	[[ "${zfsHomeDirs[*]}" =~ "${folder}" ]] && echo "true" || echo "false" # debugging
	echo # debugging

	if [[ ! "${zfsHomeDirs[*]}" =~ "${folder}" ]]; then
		# Create ZFS dataset with ACL support, in case root dataset does not have ACL support
		zfs create -o aclinherit=passthrough -o aclmode=passthrough -o acltype=posix -o xattr=sa ${ADHOMEPOOL}/${ADHOMEDATASET}/${folder}
	fi
done

echo && echo -e "\e[4mPermissions\e[0m"
# Set permissions for each username folder
for folder in "${folderHomeDirs[@]}"; do
	# Debugging: print current selected folder to set permissions for
	echo "===" && echo ${folder} && echo "==="
	# Wait for Windows' ACLs to finish applying before we apply our own
	sleep 2
	# Debugging: print current ACLs
	echo && echo "Before:"
	getfacl -pet ${ADHOMEDIR}/${folder}
	# Reset extended ACL attributes
	setfacl -R -b ${ADHOMEDIR}/${folder}
	# Set folder owner & group to username
	chown -R ${ADDOMAINNAME}\\${folder}:${ADDOMAINNAME}\\${folder} ${ADHOMEDIR}/${folder}
	# Set folder & files inside permissions to 770
	chmod -R 770 ${ADHOMEDIR}/${folder}
	# Set group sticky bit to apply group ownership to all new folder contents
	chmod g+s ${ADHOMEDIR}/${folder}
	# Debugging: print current ACLs
	echo "After:"
	getfacl -pet ${ADHOMEDIR}/${folder}
done

# Sources:
# Iterate (go through) array values to check if specified value exists: https://stackoverflow.com/a/15394738
