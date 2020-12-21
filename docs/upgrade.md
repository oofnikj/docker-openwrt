# Upgrade Guide


All commands are executed on the host running the OpenWrt container
unless otherwise specified.

Make a list of installed packages using the script provided in
`etc/list-user-installed.sh`:

    $ source openwrt.conf
    $ docker cp ./etc/list-user-installed.sh ${CONTAINER}:/tmp/
    $ docker exec $CONTAINER /tmp/list-user-installed.sh > packages

Make changes to `openwrt.conf` as necessary (refer to example).
Some parameters may have changed.

Pull (or build) the latest image for your architecture:

    $ docker pull $IMAGE:$TAG

OpenWrt contains a backup / restore utility called `sysupgrade`.
Use it to make a configuration backup archive:

    $ docker exec $CONTAINER sysupgrade --create-backup - > backup.tar.gz

Docker manages `/etc/hosts` as a bind mount. We need to ingore this file
upon restore to avoid errors, so remove it from the archive:

    $ gzip -cd backup.tar.gz | \
        tar --delete etc/hosts | \
        gzip > backup1.tar.gz
    $ mv backup1.tar.gz backup.tar.gz

**Confirm that all expected files are present in the archive before proceeding!**

At this point you may stop the old container:

    docker stop $CONTAINER

As a precaution, it's recommended to rename the old container
before deleting it outright:

    $ docker rename $CONTAINER ${CONTAINER}-backup

Run the `make clean` target to ensure the new container gets created properly.

If using `systemd`, start the OpenWrt service with `systemctl start openwrt`.
Otherwise, `make run`.

Restore the configuration:

    $ cat backup.tar.gz | \
      docker exec -i $CONTAINER sysupgrade -v --restore-backup -

Install packages:

    $ docker exec -t $CONTAINER opkg install $(cat packages)

Log in to your new OpenWrt instance and make sure everything is working. You may need to restart some services.

Once everything is confirmed working, it's safe to delete the backup container:

    $ docker rm ${CONTAINER}-backup