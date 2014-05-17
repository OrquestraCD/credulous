# This option defines which mock configuration to use -- see /etc/mock for
# the available configuration files for your system.
MOCK_CONFIG=epel-6-x86_64
SHELL=/bin/bash
DIST=$(shell grep "config_opts.*dist.*" /etc/mock/$(MOCK_CONFIG).cfg | awk '{ print $$3 }' | cut -f2 -d\' )

SRCS=credulous.go aws_iam.go credentials.go crypto.go git.go utils.go
TESTS=credulous_test.go credentials_test.go crypto_test.go git_test.go \
	testkey testkey.pub credential.json

SPEC=rpm/credulous.spec
NAME=$(shell grep '^Name:' $(SPEC) | awk '{ print $$2 }' )
VERSION=$(shell grep '^Version:' $(SPEC) | awk '{ print $$2 }' )
RELEASE=$(shell grep '^Release:' $(SPEC) | awk '{ print $$2 }' | sed -e 's/%{?dist}/.$(DIST)/' )
# only query mock if it's installed
MOCK_ROOT=$(shell type -p mock >/dev/null && /usr/bin/mock -r $(MOCK_CONFIG) --print-root-path)
MOCK_RESULT=$(shell /usr/bin/readlink -f $(MOCK_ROOT)/../result)

NVR=$(NAME)-$(VERSION)-$(RELEASE)
MOCK_SRPM=$(NVR).src.rpm
RPM=$(NVR).x86_64.rpm

.DEFAULT: all

all: mock

# This is a dirty hack for building on ubuntu build agents in Travis.
rpmbuild: sources
	@mkdir -p 	$(HOME)/rpmbuild/SOURCES \
			$(HOME)/rpmbuild/SRPMS \
			$(HOME)/rpmbuild/RPMS \
			$(HOME)/rpmbuild/SPECS \
			$(HOME)/rpmbuild/BUILD \
			$(HOME)/rpmbuild/BUILDROOT
	cp $(NAME)-$(VERSION).tar.gz $(HOME)/rpmbuild/SOURCES
	rpmbuild -bs --target x86_64 --nodeps rpm/credulous.spec
	rpmbuild -bb --target x86_64 --nodeps rpm/credulous.spec

# Create the source tarball with N-V prefix to match what the specfile expects
sources:
	tar czvf $(NAME)-$(VERSION).tar.gz --transform='s|^|src/github.com/realestate-com-au/credulous/|' $(SRCS) $(TESTS)

mock: mock-rpm
	@echo "BUILD COMPLETE; RPMS are in ."

mock-rpm: mock-srpm
	mock -r $(MOCK_CONFIG) --rebuild $(MOCK_SRPM)
	cp $(MOCK_RESULT)/$(RPM) .

mock-srpm: sources
	@echo "DIST is $(DIST)"
	@echo "RELEASE is $(RELEASE)"
	# mock -r $(MOCK_CONFIG) --init
	mock -r $(MOCK_CONFIG) --buildsrpm --spec $(SPEC) --sources .
	cp $(MOCK_RESULT)/$(MOCK_SRPM) .

clean:
	rm -f $(MOCK_SRPM) $(RPM)

allclean:
	mock -r $(MOCK_CONFIG) --clean