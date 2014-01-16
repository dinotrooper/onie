#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
#
# makefile fragment that defines the creation of onie images
#

ROOTCONFDIR		= $(CONFDIR)
SYSROOT_CPIO		= $(MBUILDDIR)/sysroot.cpio
SYSROOT_CPIO_XZ		= $(SYSROOT_CPIO).xz
UIMAGE			= $(IMAGEDIR)/$(MACHINE_PREFIX).uImage

IMAGE_BIN_STAMP		= $(STAMPDIR)/image-bin
IMAGE_UPDATER_STAMP	= $(STAMPDIR)/image-updater
IMAGE_COMPLETE_STAMP	= $(STAMPDIR)/image-complete
IMAGE			= $(IMAGE_COMPLETE_STAMP)

LSB_RELEASE_FILE = $(MBUILDDIR)/lsb-release
OS_RELEASE_FILE	 = $(MBUILDDIR)/os-release
MACHINE_CONF	 = $(MBUILDDIR)/machine.conf
RC_LOCAL	 = $(abspath $(MACHINEDIR)/rc.local)

INSTALLER_DIR	= $(abspath ../installer)

# List the packages to install
PACKAGES_INSTALL_STAMPS = \
	$(ZLIB_INSTALL_STAMP) \
	$(BUSYBOX_INSTALL_STAMP) \
	$(MTDUTILS_INSTALL_STAMP) \
	$(DROPBEAR_INSTALL_STAMP)

ifndef MAKE_CLEAN
SYSROOT_NEW_FILES = $(shell \
			test -d $(ROOTCONFDIR)/default && \
			test -f $(SYSROOT_INIT_STAMP) &&  \
			find -L $(ROOTCONFDIR)/default -mindepth 1 -cnewer $(SYSROOT_COMPLETE_STAMP) \
			  -print -quit 2>/dev/null)
  ifneq ($(SYSROOT_NEW_FILES),)
    $(shell rm -f $(SYSROOT_COMPLETE_STAMP))
  endif
  RC_LOCAL_DEP = $(shell test -r $(RC_LOCAL) && echo $(RC_LOCAL))
endif

PHONY += sysroot-check sysroot-complete

CHECKROOT	= $(MBUILDDIR)/check
CHECKDIR	= $(CHECKROOT)/checkdir
CHECKFILES	= $(CHECKROOT)/checkfiles.txt
SYSFILES	= $(CHECKROOT)/sysfiles.txt

SYSROOT_LIBS	= ld$(CLIB64)-uClibc.so.0 ld$(CLIB64)-uClibc-$(UCLIBC_VERSION).so \
		  libm.so.0 libm-$(UCLIBC_VERSION).so \
		  libgcc_s.so.1 libgcc_s.so \
		  libc.so.0 libuClibc-$(UCLIBC_VERSION).so \
		  libcrypt.so.0 libcrypt-$(UCLIBC_VERSION).so \
		  libutil.so.0 libutil-$(UCLIBC_VERSION).so

ifeq ($(REQUIRE_CXX_LIBS),yes)
  SYSROOT_LIBS += libstdc++.so libstdc++.so.6 libstdc++.so.6.0.17
endif

# sysroot-check verifies that we have all the shared libraries
# required by the executables in our final sysroot.
sysroot-check: $(SYSROOT_CHECK_STAMP)
$(SYSROOT_CHECK_STAMP): $(PACKAGES_INSTALL_STAMPS)
	$(Q) for file in $(SYSROOT_LIBS) ; do \
		sudo cp -av $(DEV_SYSROOT)/lib/$$file $(SYSROOTDIR)/lib/ || exit 1 ; \
	done
	$(Q) find $(SYSROOTDIR) -type f -print0 | xargs -0 file | grep ELF | awk -F':' '{ print $$1 }' | \
		sudo xargs $(CROSSBIN)/$(CROSSPREFIX)strip
	$(Q) sudo rm -rf $(CHECKROOT)
	$(Q) mkdir -p $(CHECKROOT) && \
	     sudo $(CROSSBIN)/$(CROSSPREFIX)populate -r $(DEV_SYSROOT) \
		-s $(SYSROOTDIR) -d $(CHECKDIR) && \
		(cd $(SYSROOTDIR) && find . > $(SYSFILES)) && \
		(cd $(CHECKDIR) && find . > $(CHECKFILES)) && \
		diff -q $(SYSFILES) $(CHECKFILES) > /dev/null 2>&1 || { \
			(echo "ERROR: Missing files in SYSROOTDIR:" && \
			 diff $(SYSFILES) $(CHECKFILES) ; \
			 false) \
		}
	$(Q) touch $@

sysroot-complete: $(SYSROOT_COMPLETE_STAMP)
$(SYSROOT_COMPLETE_STAMP): $(SYSROOT_CHECK_STAMP) $(RC_LOCAL_DEP)
	$(Q) sudo rm -f $(SYSROOTDIR)/linuxrc
	$(Q) echo "==== Installing the basic set of devices ===="
	$(Q) sudo $(SCRIPTDIR)/make-devices.pl $(SYSROOTDIR)
	$(Q) cd $(ROOTCONFDIR) && sudo ./install $(SYSROOTDIR)
	$(Q) cd $(SYSROOTDIR) && sudo ln -fs sbin/init ./init
	$(Q) rm -f $(LSB_RELEASE_FILE)
	$(Q) echo "DISTRIB_ID=onie" >> $(LSB_RELEASE_FILE)
	$(Q) echo "DISTRIB_RELEASE=$(LSB_RELEASE_TAG)" >> $(LSB_RELEASE_FILE)
	$(Q) echo "DISTRIB_DESCRIPTION=Open Network Install Environment" >> $(LSB_RELEASE_FILE)
	$(Q) rm -f $(OS_RELEASE_FILE)
	$(Q) echo "NAME=\"onie\"" >> $(OS_RELEASE_FILE)
	$(Q) echo "VERSION=\"$(LSB_RELEASE_TAG)\"" >> $(OS_RELEASE_FILE)
	$(Q) echo "ID=linux" >> $(OS_RELEASE_FILE)
	$(Q) rm -f $(MACHINE_CONF)
	$(Q) echo "onie_version=$(LSB_RELEASE_TAG)" >> $(MACHINE_CONF)
	$(Q) echo "onie_vendor_id=$(VENDOR_ID)" >> $(MACHINE_CONF)
	$(Q) echo "onie_platform=$(PLATFORM)" >> $(MACHINE_CONF)
	$(Q) echo "onie_machine=$(MACHINE)" >> $(MACHINE_CONF)
	$(Q) echo "onie_machine_rev=$(MACHINE_REV)" >> $(MACHINE_CONF)
	$(Q) echo "onie_arch=$(ARCH)" >> $(MACHINE_CONF)
	$(Q) sudo cp $(LSB_RELEASE_FILE) $(SYSROOTDIR)/etc/lsb-release
	$(Q) sudo cp $(OS_RELEASE_FILE) $(SYSROOTDIR)/etc/os-release
	$(Q) sudo cp $(MACHINE_CONF) $(SYSROOTDIR)/etc/machine.conf
	$(Q) if [ -r $(RC_LOCAL) ] ; then \
		sudo cp -a $(RC_LOCAL) $(SYSROOTDIR)/etc/rc.local ; \
	     fi
	$(Q) touch $@

# This step creates the cpio archive and compresses it
$(SYSROOT_CPIO_XZ) : $(SYSROOT_COMPLETE_STAMP)
	$(Q) echo "==== Create xz compressed sysroot for bootstrap ===="
	$(Q) ( cd $(SYSROOTDIR) && \
		sudo find . | sudo cpio --create -H newc > $(SYSROOT_CPIO) )
	$(Q) xz --compress --force --check=crc32 -8 $(SYSROOT_CPIO)
	$(Q) cp $@ $(IMAGEDIR)/$(MACHINE_PREFIX).initrd

.SECONDARY: $(IMAGEDIR)/$(MACHINE_PREFIX).itb

$(IMAGEDIR)/%.itb : $(KERNEL_INSTALL_STAMP) $(SYSROOT_CPIO_XZ)
	$(Q) echo "==== Create $* u-boot multi-file .itb image ===="
	$(Q) cd $(IMAGEDIR) && $(SCRIPTDIR)/onie-mk-itb.sh $(MACHINE) \
				$(MACHINE_PREFIX) $(SYSROOT_CPIO_XZ) $@

PHONY += image-bin
image-bin: $(IMAGE_BIN_STAMP)
$(IMAGE_BIN_STAMP): $(IMAGEDIR)/$(MACHINE_PREFIX).itb $(UBOOT_INSTALL_STAMP) $(SCRIPTDIR)/onie-mk-bin.sh
	$(Q) echo "==== Create $(MACHINE_PREFIX) ONIE binary image ===="
	$(Q) $(SCRIPTDIR)/onie-mk-bin.sh $(MACHINE_PREFIX) $(IMAGEDIR) \
		$(MACHINEDIR) $(UBOOT_DIR) $(IMAGEDIR)/onie-$(MACHINE_PREFIX).bin
	$(Q) touch $@

ifndef MAKE_CLEAN
IMAGE_UPDATER_FILES = $(shell \
			test -d $(INSTALLER_DIR) && \
			find -L $(INSTALLER_DIR) -mindepth 1 -cnewer $(IMAGE_UPDATER_STAMP) \
			  -print -quit 2>/dev/null)
  ifneq ($(IMAGE_UPDATER_FILES),)
    $(shell rm -f $(IMAGE_UPDATER_STAMP))
  endif
endif

PHONY += image-updater
image-updater: $(IMAGE_UPDATER_STAMP)
$(IMAGE_UPDATER_STAMP): $(IMAGEDIR)/$(MACHINE_PREFIX).itb $(UBOOT_INSTALL_STAMP) $(SCRIPTDIR)/onie-mk-installer.sh
	$(Q) echo "==== Create $(MACHINE_PREFIX) ONIE updater ===="
	$(Q) $(SCRIPTDIR)/onie-mk-installer.sh $(MACHINE_PREFIX) $(MACHINE_CONF) \
		$(INSTALLER_DIR) $(IMAGEDIR) $(MACHINEDIR) $(IMAGEDIR)/onie-updater-$(ARCH)-$(MACHINE_PREFIX)
	$(Q) touch $@

PHONY += image-complete
image-complete: $(IMAGE_COMPLETE_STAMP)
# $(IMAGE_COMPLETE_STAMP): $(IMAGE_BIN_STAMP) $(IMAGE_UPDATER_STAMP)
$(IMAGE_COMPLETE_STAMP): $(PLATFORM_IMAGE_COMPLETE)
	$(Q) touch $@

USERSPACE_CLEAN += image-clean
image-clean:
	$(Q) rm -f $(IMAGEDIR)/*$(MACHINE_PREFIX)* $(SYSROOT_CPIO_XZ) $(IMAGE_COMPLETE_STAMP)
	$(Q) echo "=== Finished making $@ for $(PLATFORM)"

#
################################################################################
#
# Local Variables:
# mode: makefile-gmake
# End:
