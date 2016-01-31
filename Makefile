PACKAGE = iputils
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
CFLAGS = -static -static-libgcc -Wl,-static -I$(DEP_DIR)/usr/include

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

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

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	patch -d $(BUILD_DIR) -p1 < patches/net-misc_iputils_files_iputils-20121221-add-bits_types_h.patch
	rm -rf $(BUILD_DIR)/.git
	cp -R .git/modules/upstream $(BUILD_DIR)/.git
	sed -i '/worktree/d' $(BUILD_DIR)/.git/config
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) CC=musl-gcc CFLAGS='$(CFLAGS)'
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
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

