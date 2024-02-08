# Why would you redefine BUILD_DIR? Well, maybe you want it to be mktemp -d...
BUILD_DIR ?= $(CURDIR)/build

PACKAGE_EPOCH_PREFIX = 1:
SOURCE_PACKAGE       = openssh
ORIG_VERSION         = 8.9p1
DEBIAN_VERSION       = 3ubuntu0.4
LAUNCHPAD_BASE       = https://launchpad.net/ubuntu/+archive/primary/+sourcefiles

BUILDER_DOCKER_IMAGE    = dc512-gimme-terrapin-builder
PATCHED_DOCKER_IMAGE    = dc512-gimme-terrapin-patched
TCPDUMP_DOCKER_IMAGE      = dc512-gimme-terrapin-tcpdump
VULNERABLE_DOCKER_IMAGE = dc512-gimme-terrapin-vulnerable

ORIG_TARBALL   = $(SOURCE_PACKAGE)_$(ORIG_VERSION).orig.tar.gz
DEBIAN_SPEC    = $(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).dsc
DEBIAN_TARBALL = $(SOURCE_PACKAGE)_$(ORIG_VERSION)-$(DEBIAN_VERSION).debian.tar.xz

SRC_DIR            = $(BUILD_DIR)/$(SOURCE_PACKAGE)-$(ORIG_VERSION)
SRC_FILES          = $(ORIG_TARBALL) $(DEBIAN_SPEC) $(DEBIAN_TARBALL)
BUILD_SRC_FILES    = $(patsubst %,$(BUILD_DIR)/%,$(SRC_FILES))
DOWNLOAD_SRC_FILES = $(patsubst %,downloads/%,$(SRC_FILES))

# Yes, we are deleting all the files usually found inside build and then we are
# deleting build. Why? Because we should get rid of any files we know we put
# there, and we also need to get rid of the build folder itself, but we do not
# know what BUILD_DIR might have been overridden with. It probably wasn't
# overridden, and even if it was, it was probably overridden with mktemp -d.
# But maybe some dummy ran make BUILD_DIR=${HOME} clean, in which case we do
# not need to be the ones to speed such a person's inevitable demise.
CLEAN_FILES = \
	artifacts \
	$(SRC_DIR) \
	$(BUILD_SRC_FILES) \
	build \
	demo

DIST_CLEAN_FILES = \
	downloads

.PHONY: all
all: demo/home/demo/.ssh/id_ed25519

artifacts/.stamp: $(SRC_DIR)/debian/.stamp $(SRC_DIR)/.stamp  $(BUILD_SRC_FILES) .stamp-docker-builder
	mkdir -p artifacts build
	docker run -it --rm \
		-v $(CURDIR):/srv \
		-v $(BUILD_DIR):/srv/build \
		-w /srv/build/$(SOURCE_PACKAGE)-$(ORIG_VERSION) \
		-u `id -u`:`id -g` \
		$(BUILDER_DOCKER_IMAGE) \
		debuild -us -uc
	find $(BUILD_DIR) \( -name '*.deb' -o -name '*.ddeb' \) -exec cp {} artifacts/. \;
	touch $@

$(BUILD_SRC_FILES): $(BUILD_DIR)/%: downloads/%
	mkdir -p $(BUILD_DIR)
	cp $< $@

.PHONY: clean
clean:
	-rm -rf $(CLEAN_FILES)

demo/etc/passwd:
	mkdir -p demo/etc
	echo "demo:x:$(shell id -u):$(shell id -g)::/home/demo:/bin/bash" > $@

demo/etc/ssh/sshd_host_ed25519_key: .stamp-docker-vulnerable demo/etc/passwd
	mkdir -p demo/etc/ssh
	chmod 700 demo/etc/ssh
	docker run -it --rm \
		-v $(CURDIR)/demo/home/demo:/home/demo \
		-v $(CURDIR)/demo/etc/passwd:/etc/passwd \
		-w /home/demo \
		-u `id -u`:`id -g` \
		$(VULNERABLE_DOCKER_IMAGE) \
		ssh-keygen -t ed25519 -N '' -f /etc/ssh/sshd_host_ed25519_key

demo/home/demo/.ssh/id_ed25519: .stamp-docker-vulnerable demo/etc/passwd
	mkdir -p demo/home/demo/.ssh
	chmod 700 demo/home/demo/.ssh
	docker run -it --rm \
		-v $(CURDIR)/demo/home/demo:/home/demo \
		-v $(CURDIR)/demo/etc/passwd:/etc/passwd \
		-w /home/demo \
		-u `id -u`:`id -g` \
		$(VULNERABLE_DOCKER_IMAGE) \
		ssh-keygen -t ed25519 -N '' -f .ssh/id_ed25519

.PHONY: distclean
distclean: clean
	-rm -rf $(DIST_CLEAN_FILES)downloads: $(DOWNLOAD_SRC_FILES)

$(DOWNLOAD_SRC_FILES): downloads/%:
	mkdir -p downloads
	cd downloads; wget $(LAUNCHPAD_BASE)/$(SOURCE_PACKAGE)/$(PACKAGE_EPOCH_PREFIX)$(ORIG_VERSION)-$(DEBIAN_VERSION)/$*

$(SRC_DIR)/.stamp: downloads/$(ORIG_TARBALL)
	mkdir -p $(BUILD_DIR)
	tar -C $(BUILD_DIR) -xf $(CURDIR)/$<
	touch $@

$(SRC_DIR)/debian/.stamp: downloads/$(DEBIAN_TARBALL) $(SRC_DIR)/.stamp
	tar -C $(SRC_DIR) -xf $(CURDIR)/$<
	touch $@

.stamp-docker-builder: Dockerfile.builder downloads/$(DEBIAN_SPEC)
	docker build --pull -t $(BUILDER_DOCKER_IMAGE) -f $< .
	touch $@

.stamp-docker-patched: Dockerfile.patched artifacts/.stamp
	mkdir -p demo
	docker build --pull -t $(PATCHED_DOCKER_IMAGE) -f $< .
	touch $@

.stamp-docker-tcpdump: Dockerfile.tcpdump
	mkdir -p demo
	docker build --pull -t $(TCPDUMP_DOCKER_IMAGE) -f $< .
	touch $@

.stamp-docker-vulnerable: Dockerfile.vulnerable artifacts/.stamp
	mkdir -p demo
	docker build --pull -t $(VULNERABLE_DOCKER_IMAGE) -f $< .
	touch $@
