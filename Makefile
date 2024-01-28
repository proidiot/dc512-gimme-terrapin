WGET ?= wget

PACKAGE_EPOCH_PREFIX = 1:
SOURCE_PACKAGE = openssh
ORIG_VERSION = 8.9p1
DEBIAN_VERSION = 3ubuntu0.4
LAUNCHPAD_BASE = https://launchpad.net/ubuntu/+archive/primary/+sourcefiles

BUILDER_DOCKER_IMAGE = dc512-gimme-terrapin-builder
PATCHED_DOCKER_IMAGE = dc512-gimme-terrapin-patched
VULNERABLE_DOCKER_IMAGE = dc512-gimme-terrapin-vulnerable

DEB_SRC_FILES = \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz.asc \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).debian.tar.xz \
	$(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).dsc

DOWNLOAD_SRC_FILES = $(patsubst %,downloads/%,$(DEB_SRC_FILES))

CLEAN_FILES = artifacts build demo
DIST_CLEAN_FILES = downloads

.PHONY: all
all: demo

artifacts: build/$(SOURCE_PACKAGE)-$(ORIG_VERSION)/debian $(BUILD_SRC_FILES) build/.stamp-docker-builder
	mkdir -p artifacts
	docker run -it --rm \
		-v ${PWD}:/srv -w /srv/build/$(SOURCE_PACKAGE)-$(ORIG_VERSION) \
		-u `id -u`:`id -g` \
		$(BUILDER_DOCKER_IMAGE) \
		debuild -us -uc
	find build \( -name '*.deb' -o -name '*.ddeb' \) -exec cp {} artifacts/. \;
	touch $@

$(BUILD_SRC_FILES): build/%: downloads/%
	mkdir -p build
	cp $< $@

build/.stamp-docker-builder: Dockerfile.builder $(filter %.dsc,$(DOWNLOAD_SRC_FILES))
	mkdir -p build
	docker build --pull -t $(BUILDER_DOCKER_IMAGE) -f $< .
	touch $@

build/$(SOURCE_PACKAGE)-$(ORIG_VERSION): downloads/$(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz
	cd build; tar xf $(CURDIR)/$<

build/$(SOURCE_PACKAGE)-$(ORIG_VERSION)/debian: downloads/$(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).debian.tar.xz | build/$(SOURCE_PACKAGE)-$(ORIG_VERSION)
	cd build/$(SOURCE_PACKAGE)-$(ORIG_VERSION); tar xf $(CURDIR)/$<

.PHONY: clean
clean:
	-rm -rf $(CLEAN_FILES)

downloads: $(DOWNLOAD_SRC_FILES)

$(DOWNLOAD_SRC_FILES): downloads/%:
	mkdir -p downloads
	cd downloads; $(WGET) $(LAUNCHPAD_BASE)/$(SOURCE_PACKAGE)/$(PACKAGE_EPOCH_PREFIX)$(ORIG_VERSION)-$(DEBIAN_VERSION)/$*

demo/.ssh/id_ed25519: demo/.stamp-docker-vulnerable demo/etc/passwd
	mkdir -p demo/.ssh
	chmod 700 demo/.ssh
	docker run -it --rm \
		-v $(CURDIR)/demo:/home/demo \
		-v $(CURDIR)/demo/etc/passwd:/etc/passwd \
		-w /home/demo \
		-u $(shell id -u):$(shell id -g) \
		$(VULNERABLE_DOCKER_IMAGE) \
		ssh-keygen -t ed25519 -f $(patsubst demo,,$@)

demo/.stamp-docker-patched: Dockerfile.patched artifacts
	mkdir -p demo
	docker build --pull -t $(PATCHED_DOCKER_IMAGE) -f $< .
	touch $@

demo/.stamp-docker-vulnerable: Dockerfile.vulnerable artifacts
	mkdir -p demo
	docker build --pull -t $(VULNERABLE_DOCKER_IMAGE) -f $< .
	touch $@

demo/etc/passwd:
	mkdir -p demo/etc
	echo "demo:x:$(shell id -u):$(shell id -g)::/home/demo:/bin/bash" > $@

.PHONY: distclean
distclean: clean
	-rm -rf $(DIST_CLEAN_FILES)
