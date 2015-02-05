#!/bin/sh -e

[ -z "$1" ] && { echo "Usage: $0 [url to IE.txt file]"; exit 1; }

TMP_DIR="./workdir-$(basename "$1" .txt)"

# Fetch constituent parts
wget -q -O - "$1" | dos2unix | xargs -n1 -P8 wget -c -P "$TMP_DIR"

# Identify unrar
UNRAR=unrar
if which unrar-free; then UNRAR=unrar-free ; fi
if which unrar-nonfree; then UNRAR=unrar-nonfree ; fi

# Extract VMDK from archive
$UNRAR p -inul "$TMP_DIR"/*.sfx | tar -xvC "$TMP_DIR"
VMDK="$(echo "$TMP_DIR"/*.vmdk)"

# Hack into a VMDK2 image (from https://github.com/erik-smit/one-liners/blob/master/qemu-img.vmdk3.hack.sh)
FULLSIZE=$(stat -c%s "$VMDK")
VMDKFOOTER=$(($FULLSIZE - 0x400))
VMDKFOOTERVER=$(($VMDKFOOTER  + 4))

case "`xxd -ps -s $VMDKFOOTERVER -l 1 \"$VMDK\"`" in
  03)
    echo "$VMDK is VMDK3, patching to VMDK2."
    /bin/echo -en '\x02' | dd conv=notrunc \
                              status=noxfer \
                              bs=1 \
                              seek="$VMDKFOOTERVER" \
                              of="$VMDK"
    ;;
  02)
    echo "Already a VMDK2 file"
    ;;
  default)
    echo "$VMDK is neither version 2 or 3"
    exit 1
  ;;
esac

# Convert into QCOW2
QCOW2="$(basename "$TMP_DIR"/*.ovf .ovf).qcow2"
qemu-img convert -f vmdk -O qcow2 "$VMDK" "$QCOW2"

# Remove now-useless files
rm "$VMDK" "$TMP_DIR"/*.ovf

echo Finished! Deleting "$TMP_DIR" to tidy up
ls -la "$TMP_DIR"
rm -fr "$TMP_DIR"
ln -sf "$QCOW2" "disk.qcow2"
echo Run ./start.sh '"'"$QCOW2"'"' to start IE
