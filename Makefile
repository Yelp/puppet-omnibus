PUPPET_GIT    := $(or ${upstream_puppet_git},"https://github.com/Yelp/puppet.git")
VERSION       := $(or ${puppet_version},"4.5.3")
ITERATION     := $(or ${puppet_vendor_version},y6)
PACKAGE_NAME  := "puppet-omnibus"
PKG_ITERATION := yelp-1

.PHONY: dist docker itest package clean

require_os:
	if [ -z "$(OS)" ]; then \
		echo "OS is not set, aborting"; \
		exit 1; \
	fi

dist: require_os
	mkdir -p pkg
	mkdir -p dist/$(OS)
	chmod 777 pkg dist/$(OS)

puppet_git:
	if [ -d puppet-git ] && [ -d puppet-git/.git ]; then \
		cd puppet-git;                                     \
		git clean -fdx;                                    \
		git remote set-url origin $(PUPPET_GIT);           \
		git fetch origin;                                  \
	else                                                 \
		rm -rf puppet-git;                                 \
		git clone $(PUPPET_GIT) puppet-git;                \
	fi

docker: require_os
	flock /tmp/puppet_omnibus_$(OS)_docker_build.lock \
	docker build -f Dockerfile.$(OS) -t package_puppet_omnibus_$(OS) .

package: require_os dist puppet_git docker
	docker run \
	  -e PKG_ITERATION=$(PKG_ITERATION) \
	  -e PUPPET_VERSION=$(VERSION).$(ITERATION) \
	  -e PUPPET_BASE=$(VERSION) \
	  -e HOME=/package \
	  -e EXT_UID=`id -u` \
	  -e EXT_GID=`id -g` \
	  -v `pwd`:/package_source:ro \
	  -v `pwd`/dist/$(OS):/package_dest:rw \
	  -v /etc/ssh/ssh_known_hosts:/etc/ssh/ssh_known_hosts:ro \
	  package_puppet_omnibus_$(OS) \
	  /package_source/JENKINS_BUILD.sh

itest: require_os package
	docker run \
		-v `pwd`/itest:/itest:ro \
		-v `pwd`/dist:/dist:ro \
		docker-dev.yelpcorp.com/$(OS)_yelp \
		/itest/ubuntu.sh \
		/dist/$(OS)/$(PACKAGE_NAME)_$(VERSION)-$(PKG_ITERATION)_amd64.deb \
		$(VERSION)

clean:
	rm -rf dist/ cache/ pkg/

itest_%:
	OS=$* make itest
