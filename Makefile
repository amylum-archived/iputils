PACKAGE = iputils
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
CFLAGS = -I$(DEP_DIR)/usr/include

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/s//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBCAP_VERSION = 2.25-4
LIBCAP_URL = https://github.com/amylum/libcap/releases/download/$(LIBCAP_VERSION)/libcap.tar.gz
LIBCAP_TAR = /tmp/libcap.tar.gz
LIBCAP_DIR = /tmp/libcap
LIBCAP_PATH = -I$(LIBCAP_DIR)/usr/include -L$(LIBCAP_DIR)/usr/lib

LIBGCRYPT_VERSION = 1.7.3-11
LIBGCRYPT_URL = https://github.com/amylum/libgcrypt/releases/download/$(LIBGCRYPT_VERSION)/libgcrypt.tar.gz
LIBGCRYPT_TAR = /tmp/libgcrypt.tar.gz
LIBGCRYPT_DIR = /tmp/libgcrypt
LIBGCRYPT_PATH = -I$(LIBGCRYPT_DIR)/usr/include -L$(LIBGCRYPT_DIR)/usr/lib

LIBGPG-ERROR_VERSION = 1.24-6
LIBGPG-ERROR_URL = https://github.com/amylum/libgpg-error/releases/download/$(LIBGPG-ERROR_VERSION)/libgpg-error.tar.gz
LIBGPG-ERROR_TAR = /tmp/libgpgerror.tar.gz
LIBGPG-ERROR_DIR = /tmp/libgpg-error
LIBGPG-ERROR_PATH = -I$(LIBGPG-ERROR_DIR)/usr/include -L$(LIBGPG-ERROR_DIR)/usr/lib

LIBIDN_VERSION = 1.33-2
LIBIDN_URL = https://github.com/amylum/libidn/releases/download/$(LIBIDN_VERSION)/libidn.tar.gz
LIBIDN_TAR = /tmp/libidn.tar.gz
LIBIDN_DIR = /tmp/libidn
LIBIDN_PATH = -I$(LIBIDN_DIR)/usr/include -L$(LIBIDN_DIR)/usr/lib

NETTLE_VERSION = 3.2-4
NETTLE_URL = https://github.com/amylum/nettle/releases/download/$(NETTLE_VERSION)/nettle.tar.gz
NETTLE_TAR = /tmp/nettle.tar.gz
NETTLE_DIR = /tmp/nettle
NETTLE_PATH = -I$(NETTLE_DIR)/usr/include -L$(NETTLE_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(DEP_DIR)
	mkdir -p $(DEP_DIR)/usr/include
	cp -R /usr/include/{linux,asm,asm-generic} $(DEP_DIR)/usr/include/
	rm -rf $(LIBCAP_DIR) $(LIBCAP_TAR)
	mkdir $(LIBCAP_DIR)
	curl -sLo $(LIBCAP_TAR) $(LIBCAP_URL)
	tar -x -C $(LIBCAP_DIR) -f $(LIBCAP_TAR)
	rm -rf $(LIBGCRYPT_DIR) $(LIBGCRYPT_TAR)
	mkdir $(LIBGCRYPT_DIR)
	curl -sLo $(LIBGCRYPT_TAR) $(LIBGCRYPT_URL)
	tar -x -C $(LIBGCRYPT_DIR) -f $(LIBGCRYPT_TAR)
	rm -rf $(LIBGPG-ERROR_DIR) $(LIBGPG-ERROR_TAR)
	mkdir $(LIBGPG-ERROR_DIR)
	curl -sLo $(LIBGPG-ERROR_TAR) $(LIBGPG-ERROR_URL)
	tar -x -C $(LIBGPG-ERROR_DIR) -f $(LIBGPG-ERROR_TAR)
	rm -rf $(LIBIDN_DIR) $(LIBIDN_TAR)
	mkdir $(LIBIDN_DIR)
	curl -sLo $(LIBIDN_TAR) $(LIBIDN_URL)
	tar -x -C $(LIBIDN_DIR) -f $(LIBIDN_TAR)
	rm -rf $(NETTLE_DIR) $(NETTLE_TAR)
	mkdir $(NETTLE_DIR)
	curl -sLo $(NETTLE_TAR) $(NETTLE_URL)
	tar -x -C $(NETTLE_DIR) -f $(NETTLE_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	patch -d $(BUILD_DIR) -p1 < patches/s20160308-ai-idn.patch
	rm -rf $(BUILD_DIR)/.git
	cp -R .git/modules/upstream $(BUILD_DIR)/.git
	sed -i '/worktree/d' $(BUILD_DIR)/.git/config
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBCAP_PATH) $(LIBGCRYPT_PATH) $(LIBGPG-ERROR_PATH) $(LIBIDN_PATH) $(NETTLE_PATH)' LDFLAGS='$(LIBCAP_PATH) $(LIBGCRYPT_PATH) $(LIBGPG-ERROR_PATH) $(LIBIDN_PATH) $(NETTLE_PATH)'
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE) $(RELEASE_DIR)/usr/bin
	find $(BUILD_DIR) -maxdepth 1 -type f -executable | xargs -I{} cp {} $(RELEASE_DIR)/usr/bin
	chmod 4755 $(RELEASE_DIR)/usr/bin/ping
	cp $(BUILD_DIR)/ninfod/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

