SHELL:=/bin/bash
CURDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
TMPDIR=$(CURDIR)/tmp/
ARTIFACTDIR:=$(CURDIR)/artifacts

.PHONY: all software clean

all: software

bootrom/bootrom:
	$(MAKE) -C bootrom all 

addram/addram:
	$(MAKE) -C addram all

maprom/maprom:
	$(MAKE) -C maprom all

software: bootrom/bootrom addram/addram maprom/maprom

clean:
	$(MAKE) -C bootrom clean
	$(MAKE) -C addram clean
	$(MAKE) -C maprom clean
	rm -rf $(ARTIFACTDIR)
	rm -rf $(TMPDIR)

package: addram/addram bootrom/bootrom maprom/maprom
	rm -rf $(TMPDIR)
	mkdir -p $(TMPDIR)
	mkdir -p $(ARTIFACTDIR)
	cp $^ $(TMPDIR)
	cd $(TMPDIR) && xdftool $(ARTIFACTDIR)/RIDE-Software.adf format RIDE $(addprefix + write ,$(notdir $^))
	cd $(TMPDIR) && lha -c $(ARTIFACTDIR)/RIDE-Software.lha $(notdir $^)