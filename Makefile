WGET ?= wget

PACKAGE_EPOCH_PREFIX = 1:
SOURCE_PACKAGE = openssh
ORIG_VERSION = 8.9p1
DEBIAN_VERSION = 3ubuntu0.4

DEB_SRC_FILES = \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz.asc \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).debian.tar.xz \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).dsc

DOWNLOAD_SRC_FILES = $(patsubst %,downloads/%,$(DEB_SRC_FILES))
BUILD_SRC_FILES = $(patsubst %,build/%,$(DEB_SRC_FILES))

CLEAN_FILES = artifacts build
DIST_CLEAN_FILES = downloads

.PHONY: all
all: artifacts

artifacts: build/$(SOURCE_PACKAGE)-$(ORIG_VERSION)/debian $(BUILD_SRC_FILES)
	mkdir -p artifacts
	docker run -it --rm -v ${PWD}:/srv -w /srv/build ubuntu:22.04 /srv/setup-and-debuild.sh
	find build -name '*.deb' -o -name '*.ddeb' -exec cp {} artifacts/. \;

$(BUILD_SRC_FILES): build/%: downloads/%
	mkdir -p build
	cp $< $@

build/$(SOURCE_PACKAGE)-$(ORIG_VERSION): downloads/$(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz
	cd build; tar xf $(CURDIR)/$<

build/$(SOURCE_PACKAGE)-$(ORIG_VERSION)/debian: build/$(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).debian.tar.xz build/$(SOURCE_PACKAGE)-$(ORIG_VERSION)
	cd build/$(SOURCE_PACKAGE)-$(ORIG_VERSION); tar xf $(CURDIR)/$<

.PHONY: clean
clean:
	-rm -rf $(CLEAN_FILES)

downloads: $(DOWNLOAD_SRC_FILES)

$(DOWNLOAD_SRC_FILES): downloads/%:
	mkdir -p downloads
	cd downloads; $(WGET) https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/$(SOURCE_PACKAGE)/$(PACKAGE_EPOCH_PREFIX)$(ORIG_VERSION)-$(DEBIAN_VERSION)/$*

.PHONY: distclean
distclean: clean
	-rm -rf $(DIST_CLEAN_FILES)
