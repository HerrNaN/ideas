default: ideas
all: binaries documentation

.PHONY: test

SRCDIR = src

VERSION = 1.0.10

include Makefile.incl

binaries: ideas ideasWX

ideas: $(BINDIR)/ideas.cgi
ideasWX: $(BINDIR)/ideasWX$(EXE)
prof-ideas: $(BINDIR)/prof-ideas$(EXE)
prof: prof-ideas.prof
assess: $(BINDIR)/assess$(EXE)

$(BINDIR)/ideas.cgi: $(HS-SOURCES) revision
	$(MKDIR) -p $(BINDIR) $(OUTDIR)
	$(GHC) $(GHCFLAGS) -o $@ src/Main.hs
	$(STRIP) $@

$(BINDIR)/ideasWX$(EXE): $(BINDIR)/ounl.jpg $(BINDIR)/ideas.ico $(BINDIR)/ideas.jpg $(HS-SOURCES) tools/IdeasWX/IdeasWX.hs revision
ifeq ($(WX), yes)
	$(MKDIR) -p $(BINDIR) $(OUTDIR)
	$(GHC) $(GHCFLAGS) $(GHCGUIFLAGS) -itools/IdeasWX -o $@ tools/IdeasWX/IdeasWX.hs
	$(STRIP) $@
ifeq ($(WINDOWS), no)
	$(CD) $(BINDIR); $(MAC) ideasWX
endif
endif

# For profiling purposes
$(BINDIR)/prof-ideas$(EXE): $(HS-SOURCES) revision
	$(MKDIR) -p $(BINDIR) $(PROFDIR)
	$(GHC) $(PROFFLAGS) -o $@ src/Main.hs
	$(STRIP) $@

prof-ideas.prof: $(BINDIR)/prof-ideas$(EXE)
	$(BINDIR)/prof-ideas$(EXE) --test +RTS -p

$(BINDIR)/ounl.jpg: tools/IdeasWX/ounl.jpg
	$(MKDIR) -p $(BINDIR)
	$(CP) $< $@

$(BINDIR)/ideas.ico: tools/IdeasWX/ideas.ico
	$(MKDIR) -p $(BINDIR)
	$(CP) $< $@

$(BINDIR)/ideas.jpg: tools/IdeasWX/ideas.jpg
	$(MKDIR) -p $(BINDIR)
	$(CP) $< $@

# Create the assessment binary
$(BINDIR)/assess$(EXE): ag
	$(MKDIR) -p $(BINDIR) $(OUTDIR)
	$(GHC) $(GHCFLAGS) $(HELIUMFLAGS) -o $@ $(SRCDIR)/Domain/Programming/Main.hs
	$(STRIP) $@

#---------------------------------------------------------------------------------------
# Other directories

documentation: docs $(BINDIR)/ideas.cgi
	make -C $(DOCDIR) || exit 1

pages: docs $(BINDIR)/ideas.cgi
	make -C $(DOCDIR) pages || exit 1

test: 
	$(BINDIR)/ideas.cgi --test

# $(TESTDIR)/test.log
# $(TESTDIR)/test.log: $(HS-SOURCES) $(BINDIR)/ideas.cgi
# 	make -C $(TESTDIR) || exit 1

#---------------------------------------------------------------------------------------
# Helper targets

ghci: revision
	$(MKDIR) -p $(OUTDIR)
	$(GHCI) -i$(SRCDIR) -itools -itools/IdeasWX -odir $(OUTDIR) -hidir $(OUTDIR) $(GHCWARN)

HELIUMDIR = ../../../heliumsystem/helium/src
TOPDIR = ../../../heliumsystem/Top/src
LVMDIR = ../../../heliumsystem/lvm/src/

HELIUMFLAGS = -i$(HELIUMDIR)/utils \
		-i$(HELIUMDIR)/staticanalysis/staticchecks -i$(HELIUMDIR)/staticanalysis/inferencers \
		-i$(HELIUMDIR)/staticanalysis/messages -i$(HELIUMDIR)/main -i$(TOPDIR) \
		-i$(HELIUMDIR)/staticanalysis/miscellaneous -i$(HELIUMDIR)/syntax -i$(LVMDIR)/lib/common \
		-i$(LVMDIR)/lib/common/ghc -i$(HELIUMDIR)/modulesystem -i$(HELIUMDIR)/staticanalysis/directives \
		-i$(HELIUMDIR)/staticanalysis/heuristics -i$(HELIUMDIR)/parser -i$(HELIUMDIR)/codegeneration \
		-i$(LVMDIR)/lib/lvm -i$(LVMDIR)/lib/asm -i$(LVMDIR)/lib/core

helium: ag # revision
	$(MKDIR) -p $(OUTDIR)
	$(GHCI) -optc-m32 -opta-m32 -optl-m32 $(HELIUMFLAGS) -i$(SRCDIR) -itools/IdeasWX -odir $(OUTDIR) -hidir $(OUTDIR) $(GHCWARN)


run: ideasWX
ifeq ($(WINDOWS), yes)
	$(BINDIR)/ideasWX$(EXE)
else
	open $(BINDIR)/ideasWX.app/
endif

revision: $(SRCDIR)/Main/Revision.hs

$(SRCDIR)/Main/Revision.hs: $(filter-out $(SRCDIR)/Main/Revision.hs, $(HS-SOURCES))
	echo "-- Automatically generated by Makefile.  Do not change." > $@
	echo "module Main.Revision where" >> $@
	echo "version :: String" >> $@
	echo 'version = "$(VERSION)"' >> $@
ifeq ($(SVN), yes)
	echo 'revision :: Int' >> $@
	svn info | grep 'Revision' | sed 's/.*\: /revision = /' >> $@
	echo 'lastChanged :: String ' >> $@
	svn info | grep 'Last Changed Date' | sed 's/.*(\(.*\))/lastChanged = \"\1\"/' >> $@
else
	echo 'revision :: Int' >> $@
	echo 'revision = 0' >> $@
	echo 'lastChanged :: String ' >> $@
	echo 'lastChanged = "unknown"' >> $@
endif

nolicense:
	find src -name \*.hs -print0 | xargs --null grep -L "LICENSE"

#-------------------------------------------------------------------------
# AG sources
AG-SOURCES = $(SRCDIR)/Domain/Programming/AlphaRenaming.hs \
             $(SRCDIR)/Domain/Programming/InlinePatternBindings.hs

ag : $(AG-SOURCES)

$(SRCDIR)/Domain/Programming/AlphaRenaming.hs : \
		$(SRCDIR)/Domain/Programming/AlphaRenaming.ag \
		$(HELIUMDIR)/staticanalysis/staticchecks/Scope.ag \
		$(HELIUMDIR)/syntax/UHA_Syntax.ag 

	# AG AlphaRenaming
	cd $(SRCDIR)/Domain/Programming;\
	$(AG) $(AG_OPTS) --self --module=Domain.Programming.AlphaRenaming \
	-P ../../../$(HELIUMDIR) AlphaRenaming.ag;\
	cd ../../..

$(SRCDIR)/Domain/Programming/InlinePatternBindings.hs : \
		$(SRCDIR)/Domain/Programming/InlinePatternBindings.ag \
		$(HELIUMDIR)/syntax/UHA_Syntax.ag 

	# AG InlinePatternBindings
	cd $(SRCDIR)/Domain/Programming;\
	$(AG) $(AG_OPTS) --self --module=Domain.Programming.InlinePatternBindings \
	-P ../../../$(HELIUMDIR) InlinePatternBindings.ag;\
	cd ../../..


#-------------------------------------------------------------------------
# Installing on the IDEAS server

ifeq ($(IDEASSERVER), yes)

INSTALL-CGI    = /var/www/cgi-bin
INSTALL-DOC    = /var/www/docs/latest
INSTALL-SCRIPT = /var/www/cgi-bin/scripts

install: ideas
	# "sudo make install"
	$(CP) $(BINDIR)/ideas.cgi $(INSTALL-CGI)
	$(CP) -r $(DOCDIR)/* $(INSTALL-DOC)
	$(CP) $(SCRIPTDIR)/* $(INSTALL-SCRIPT)
	$(CHMOD) 744 $(INSTALL-SCRIPT)/*

endif
	
#---------------------------------------------------------------------------------------
# Cleaning up

clean:
	$(RM) -rf $(BINDIR)
	$(RM) -rf $(OUTDIR)
	make -C $(DOCDIR)  clean
	make -C $(TESTDIR) clean
	$(RM) -f $(AG-SOURCES)
