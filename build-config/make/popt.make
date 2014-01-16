#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
#
# This is a makefile fragment that defines the build of popt
#

POPT_VERSION		= 1.16
POPT_TARBALL		= popt-$(POPT_VERSION).tar.gz
POPT_TARBALL_URLS	+= $(ONIE_MIRROR) http://rpm5.org/files/popt/
POPT_BUILD_DIR		= $(MBUILDDIR)/popt
POPT_DIR		= $(POPT_BUILD_DIR)/popt-$(POPT_VERSION)

POPT_SRCPATCHDIR	= $(PATCHDIR)/popt
POPT_DOWNLOAD_STAMP	= $(DOWNLOADDIR)/popt-download
POPT_SOURCE_STAMP	= $(STAMPDIR)/popt-source
POPT_PATCH_STAMP	= $(STAMPDIR)/popt-patch
POPT_CONFIGURE_STAMP	= $(STAMPDIR)/popt-configure
POPT_BUILD_STAMP	= $(STAMPDIR)/popt-build
POPT_INSTALL_STAMP	= $(STAMPDIR)/popt-install
POPT_STAMP		= $(POPT_SOURCE_STAMP) \
			  $(POPT_PATCH_STAMP) \
			  $(POPT_CONFIGURE_STAMP) \
			  $(POPT_BUILD_STAMP) \
			  $(POPT_INSTALL_STAMP)

PHONY += popt popt-download popt-source popt-patch \
	 popt-configure popt-build popt-install popt-clean \
	 popt-download-clean

POPT_LIBS = libpopt.so libpopt.so.0 libpopt.so.0.0.0

popt: $(POPT_STAMP)

DOWNLOAD += $(POPT_DOWNLOAD_STAMP)
popt-download: $(POPT_DOWNLOAD_STAMP)
$(POPT_DOWNLOAD_STAMP): $(PROJECT_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Getting upstream popt ===="
	$(Q) $(SCRIPTDIR)/fetch-package $(DOWNLOADDIR) $(UPSTREAMDIR) \
		$(POPT_TARBALL) $(POPT_TARBALL_URLS)
	$(Q) touch $@

SOURCE += $(POPT_SOURCE_STAMP)
popt-source: $(POPT_SOURCE_STAMP)
$(POPT_SOURCE_STAMP): $(TREE_STAMP) | $(POPT_DOWNLOAD_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Extracting upstream popt ===="
	$(Q) $(SCRIPTDIR)/extract-package $(POPT_BUILD_DIR) $(DOWNLOADDIR)/$(POPT_TARBALL)
	$(Q) touch $@

popt-patch: $(POPT_PATCH_STAMP)
$(POPT_PATCH_STAMP): $(POPT_SRCPATCHDIR)/* $(POPT_SOURCE_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Patching popt ===="
	$(Q) $(SCRIPTDIR)/apply-patch-series $(POPT_SRCPATCHDIR)/series $(POPT_DIR)
	$(Q) touch $@

ifndef MAKE_CLEAN
POPT_NEW_FILES = $(shell test -d $(POPT_DIR) && test -f $(POPT_BUILD_STAMP) && \
	              find -L $(POPT_DIR) -newer $(POPT_CONFIGURE_STAMP) -type f -print -quit)
endif

popt-configure: $(POPT_CONFIGURE_STAMP)
$(POPT_CONFIGURE_STAMP): $(POPT_PATCH_STAMP) $(POPT_NEW_FILES) | $(DEV_SYSROOT_INIT_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "====  Configure popt-$(POPT_VERSION) ===="
	$(Q) cd $(POPT_DIR) && PATH='$(CROSSBIN):$(PATH)'	\
		$(POPT_DIR)/configure				\
		--prefix=$(DEV_SYSROOT)/usr			\
		--host=$(TARGET)				\
		--disable-nls					\
		CC=$(CROSSPREFIX)gcc				\
		CFLAGS="$(ONIE_CFLAGS) -DONIE_UCLIBC"		\
		LDFLAGS="$(ONIE_LDFLAGS)"
	$(Q) touch $@

popt-build: $(POPT_BUILD_STAMP)
$(POPT_BUILD_STAMP): $(POPT_CONFIGURE_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "====  Building popt-$(POPT_VERSION) ===="
	$(Q) PATH='$(CROSSBIN):$(PATH)'	$(MAKE) -C $(POPT_DIR)
	$(Q) touch $@

popt-install: $(POPT_INSTALL_STAMP)
$(POPT_INSTALL_STAMP): $(SYSROOT_INIT_STAMP) $(POPT_BUILD_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Installing popt in $(DEV_SYSROOT) ===="
	$(Q) sudo PATH='$(CROSSBIN):$(PATH)'			\
		$(MAKE) -C $(POPT_DIR) install
	$(Q) for file in $(POPT_LIBS) ; do \
		sudo cp -av $(DEV_SYSROOT)/usr/lib/$$file $(SYSROOTDIR)/usr/lib/ ; \
	done
	$(Q) touch $@

USERSPACE_CLEAN += popt-clean
popt-clean:
	$(Q) rm -rf $(POPT_BUILD_DIR)
	$(Q) rm -f $(POPT_STAMP)
	$(Q) echo "=== Finished making $@ for $(PLATFORM)"

CLEAN_DOWNLOAD += popt-download-clean
popt-download-clean:
	$(Q) rm -f $(POPT_DOWNLOAD_STAMP) $(DOWNLOADDIR)/popt*

#-------------------------------------------------------------------------------
#
# Local Variables:
# mode: makefile-gmake
# End:
