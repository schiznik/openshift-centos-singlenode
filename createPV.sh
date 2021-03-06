#!/bin/bash

#define ZFS pool to host NFS exports
ZPOOL=exports

#define temporary vol.yaml
VOLYAML=$(mktemp /tmp/vol.XXXXXXX.yaml)

while IFS=$',' read -r project dataname size ; do

	#create dataset - create parent manually before running this script
	zfs create $ZPOOL/"${project}"/"${dataname}"
	
	#dirty haxx
	chgrp -R 0 /$ZPOOL/"${project}"/"${dataname}"
	chmod -R go+rwx /$ZPOOL/"${project}"/"${dataname}"

	#set SELinux context
	chcon -Rt svirt_sandbox_file_t /$ZPOOL/"${project}"/"${dataname}"

	# Yawn....
	sleep 5

	#modify vol.yaml & oc create it
	cp -Zf vol.yaml.default "$VOLYAML"
	sed -i "s/VOL_NAME/${dataname}/g" "$VOLYAML"
	sed -i "s/VOL_PATH/$ZPOOL\/${project}\/${dataname}/g" "$VOLYAML"
	sed -i "s/VOL_SIZE/${size}/g" "$VOLYAML"
	sed -i "s/VOL_PROJECT/${project}/g" "$VOLYAML"
	oc create -f "$VOLYAML"

	#add to /etc/exports & refresh mount list
	echo "/$ZPOOL/${project}/${dataname}	*(rw,sync,no_root_squash,no_all_squash)" >> /etc/exports
	exportfs -rv

	echo "created ${size}Gi volume ${dataname}"
done < "oc-volume-list"
