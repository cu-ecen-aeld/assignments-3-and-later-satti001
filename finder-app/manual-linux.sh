#!/bin/sh
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
       # Deep clean existing kernel configuration files
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper

    # Create default kernel configuration
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    # Build Kernel image
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all

    # Build Kernel modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules

    # Build Kernel devicetree
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

    echo "Finished building kernel image"
    
   
fi

echo "Adding the Image in outdir"
echo "Adding the Image in outdir"
cd $OUTDIR
cp -a linux-stable/arch/arm64/boot/Image ./

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories

# Create necessary base directories
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir usr/bin usr/lib usr/sbin
mkdir -p var/log


cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean
    make defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
# Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX="${OUTDIR}/rootfs" install

# Cross-compile sysroot dir
CCSYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)


echo "Library dependencies"
cd "${OUTDIR}/rootfs"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"


# Interpreter / LIBS dependecies
REQ_INTRP=$(${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter" | awk '{ gsub(/\[|\]/,"",$NF); print $NF}')
REQ_LIBS=$(${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library" | awk '{ gsub(/\[|\]/,"",$NF); print $NF}')

# TODO: Add library dependencies to rootfs
for intrp in $REQ_INTRP
do
    echo "intrp: $intrp"
	intrp=$(basename ${intrp})
	LIB_SRC=$(find ${CCSYSROOT} -name $intrp)
	LIB_TGT=$(realpath --no-symlinks --relative-to=$CCSYSROOT $LIB_SRC)
	
	echo "Copy $LIB_SRC to $LIB_TGT"
	cp -a $LIB_SRC $LIB_TGT
	
    if [ -L $LIB_TGT ]; then
		LNK_SRC=$(readlink -f $LIB_SRC)
	    LNK_TGT=$(realpath --relative-to=$CCSYSROOT $LIB_SRC)
		echo "Copy link: $LNK_SRC to $LNK_TGT"
		cp -a $LNK_SRC $LNK_TGT
    fi
done


for lib in $REQ_LIBS
do
    lib=$(basename ${lib})
	LIB_SRC=$(find ${CCSYSROOT} -name $lib)
	LIB_TGT=$(realpath --no-symlinks --relative-to=$CCSYSROOT $LIB_SRC)
	echo "Copy $LIB_SRC to $LIB_TGT"
	cp -a $LIB_SRC $LIB_TGT

	LNKTGT=$(realpath --relative-to=$CCSYSROOT $LIB_SRC)
	
    # If src is link, copy link target locally
    if [ -L $LIB_TGT ]; then
		LNK_SRC=$(readlink -f $LIB_SRC)
	    LNK_TGT=$(realpath --relative-to=$CCSYSROOT $LIB_SRC)
		echo "Copy link: $LNK_SRC to $LNK_TGT"
		cp -a $LNK_SRC $LNK_TGT
    fi
done

cd ${ROOTFS_DIR}

# TODO: Make device nodes
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# TODO: Clean and build the writer utility
cd $FINDER_APP_DIR
make clean
make CROSS_COMPILE=$CROSS_COMPILE

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp -a $FINDER_APP_DIR/writer $ROOTFS_DIR/home/
echo -e "Copy finder app dir to rootfs/home"
cp -a $FINDER_APP_DIR/finder.sh $ROOTFS_DIR/home/
mkdir $ROOTFS_DIR/home/conf
cp -a $FINDER_APP_DIR/conf/username.txt $ROOTFS_DIR/home/conf/
cp -a $FINDER_APP_DIR/finder-test.sh $ROOTFS_DIR/home/
cp -a $FINDER_APP_DIR/autorun-qemu.sh $ROOTFS_DIR/home/


# TODO: Chown the root directory
cd "${OUTDIR}/rootfs"
sudo chown -R root:root *
# TODO: Create initramfs.cpio.gz

cd $ROOTFS_DIR
find . | cpio -H newc -ov --owner root:root > ../initramfs.cpio
cd ..
gzip -f initramfs.cpio
