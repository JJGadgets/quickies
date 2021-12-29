#!/bin/bash

## By JJGadgets
## This script is to be run via incron/watcher. On a distro supporting systemd & journalctl, it can be helpful to set incron/watcher command to run on event as: /usr/bin/systemd-cat -t ZFS-AD-home /path/to/ZFS-AD-home.sh
## It will detect if user folders in your Active Directory user home directory ZFS dataset have a corresponding ZFS dataset, and creates a dataset in place of folder if dataset not found.

echo "Script is running as: ${USER}"
#set -Eeuo pipefail

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

# TODO: ZFS parent dataset creation
# if ZFS parent dataset (via zfs list ${ADHOMEPOOL}/${ADHOMEDATASET}) does not exist
#zfs create -o aclinherit=passthrough -o aclmode=passthrough -o acltype=nfsv4 -o xattr=sa ${ADHOMEPOOL}/${ADHOMEDATASET}
#sleep 1
#chown -R root:${ADDOMAINNAME}\\domain\ users
#nfs4xdr_setfacl -s owner@:rwxpDdaARWcCos:fd-----:allow,group@:-wxp--aARWcCos:-------:allow ${ADHOMEDIR}

# TODO: clean up script output

# ZFS dataset creation for folders without ZFS datasets
echo && echo -e "\e[4mDoes ZFS dataset exist for folder name?\e[0m"
# For each username folder, if no ZFS dataset exists for username, create dataset
for folder in "${folderHomeDirs[@]}"; do
	echo "${folder}" # debugging
	[[ "${zfsHomeDirs[*]}" =~ "${folder}" ]] && echo "true" || echo "false" # debugging
	echo # debugging

	if [[ ! "${zfsHomeDirs[*]}" =~ "${folder}" ]]; then
		# Create ZFS dataset with ACL support, in case root dataset does not have ACL support
		zfs create -o aclinherit=passthrough -o aclmode=passthrough -o acltype=nfsv4 -o xattr=sa ${ADHOMEPOOL}/${ADHOMEDATASET}/${folder}

		# TODO: sync user data that isn't in ZFS dataset into ZFS dataset, run a few more times to ensure data is up to date, and then swap to ZFS dataset
		#if directory is not empty before ZFS dataset is mounted
			# ZFS snapshot & rsync that
			# continuous rsync of current dataset data till data is up to date according to last rsync run (rsync -aiuxhvvHAXS --partial --info=progress2 --stats) (can rsync daemon ensure up to date?)
			# mv rename old folder && recreate current folder with same permissions && zfs mount command below
		zfs mount ${ADHOMEPOOL}/{$ADHOMEDATASET}/${folder} # indent once above is implemented
			# rsync renamed old folder to new dataset until both up to date, then (DESTRUCTIVE) rm -rf old folder
	fi
done

# Permissions
echo && echo -e "\e[4mPermissions\e[0m" && echo "Waiting for Windows to apply their ACLs"
# Wait for Windows' ACLs to finish applying before we apply our own
sleep 5
# Set permissions for each username folder
for folder in "${folderHomeDirs[@]}"; do
	# Debugging: print current selected folder to set permissions for
	echo "===" && echo ${folder} && echo "==="
	# Debugging: print current ACLs
	echo && echo "Before:"
	getfacl -pet ${ADHOMEDIR}/${folder}
	nfs4xdr_getfacl ${ADHOMEDIR}/${folder}
	# Reset extended ACL attributes for POSIX ACL
	setfacl -R -b ${ADHOMEDIR}/${folder}
	# Set folder owner & group to username
	chown -R ${ADDOMAINNAME}\\${folder}:${ADDOMAINNAME}\\${folder} ${ADHOMEDIR}/${folder}
	# Set POSIX ACL permissions for folder & contents inside to 770 (commented out in favour for NFSv4 ACLs)
	# chmod -R 770 ${ADHOMEDIR}/${folder}
	# Set group sticky bit to apply group ownership to all new folder contents for POSIX ACL (commented out in favour for NFSv4 ACLs)
	# chmod g+s ${ADHOMEDIR}/${folder}
	# Set NFSv4 ACL permissions for folder & contents inside to effectively 770 (apparently, this is unnecessary because using NFSv4 ACLs with Home folder specified already sets strict ACLs where only admins and CREATOR OWNER can access the folder and contents
	nfs4xdr_setfacl -s owner@:rwxpDdaARWcCos:fd-----:allow,group@:rwxpDdaARWcCos:fd-----:allow,everyone@:--------------:-------:allow ${ADHOMEDIR}/${folder}
	# Debugging: print current ACLs
	echo "After:"
	getfacl -pet ${ADHOMEDIR}/${folder}
	nfs4xdr_getfacl ${ADHOMEDIR}/${folder}
done

# Sources:
# Iterate (go through) array values to check if specified value exists: https://stackoverflow.com/a/15394738
