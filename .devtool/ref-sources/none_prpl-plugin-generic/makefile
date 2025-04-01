include makefile.inc

NOW = $(shell date +"%Y-%m-%d(%H:%M:%S %z)")

# Extra destination directories
PKGDIR = ./output/$(MACHINE)/pkg/

# Targets
all:
	$(MAKE) -C src all

clean:
	$(MAKE) -C src clean

install: all
    
	$(INSTALL) -D -p -m 0644 odl/demo_sync_hostname.odl $(DEST)/etc/amx/demo/demo_sync_hostname.odl
	$(INSTALL) -D -p -m 0644 odl/demo_definition.odl $(DEST)/etc/amx/demo/demo_definition.odl
	$(INSTALL) -D -p -m 0644 odl/demo.odl $(DEST)/etc/amx/demo/demo.odl
	$(INSTALL) -D -p -m 0755 odl/demo.odl $(DEST)/usr/bin/demo.odl
	$(INSTALL) -D -p -m 0644 output/$(MACHINE)/object/demo.so $(DEST)/usr/lib/amx/demo/demo.so
	$(INSTALL) -d -m 0755 $(DEST)$(BINDIR)
	ln -sfr $(DEST)$(BINDIR)/amxrt $(DEST)$(BINDIR)/demo


package: all

	$(INSTALL) -D -p -m 0644 odl/demo_sync_hostname.odl $(PKGDIR)/etc/amx/demo/demo_sync_hostname.odl
	$(INSTALL) -D -p -m 0644 odl/demo_definition.odl $(PKGDIR)/etc/amx/demo/demo_definition.odl
	$(INSTALL) -D -p -m 0644 odl/demo.odl $(PKGDIR)/etc/amx/demo/demo.odl
	$(INSTALL) -D -p -m 0755 odl/demo.odl $(PKGDIR)/usr/bin/demo.odl
	$(INSTALL) -D -p -m 0644 output/$(MACHINE)/object/demo.so $(PKGDIR)/usr/lib/amx/demo/demo.so
	$(INSTALL) -d -m 0755 $(PKGDIR)$(BINDIR)
	ln -sfr $(PKGDIR)$(BINDIR)/amxrt $(PKGDIR)$(BINDIR)/demo
	cd $(PKGDIR) && $(TAR) -czvf ../$(COMPONENT)-$(VERSION).tar.gz .
	cp $(PKGDIR)../$(COMPONENT)-$(VERSION).tar.gz .
	make -C packages

.PHONY: all clean changelog install package doc test
