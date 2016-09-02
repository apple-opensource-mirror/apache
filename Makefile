##
# Makefile for apache
##
# Wilfredo Sanchez | wsanchez@apple.com
##

# Project info
Project         = apache
UserType        = Administration
ToolType        = Services
GnuAfterInstall = install-local

# It's a GNU Source project
# Well, not really but we can make it work.
include $(MAKEFILEPATH)/CoreOS/ReleaseControl/GNUSource.make

# Automatic Extract & Patch
AEP            = YES
AEP_Project    = $(Project)
AEP_Version    = 1.3.33
AEP_ProjVers   = $(AEP_Project)_$(AEP_Version)
AEP_Filename   = $(AEP_ProjVers).tar.gz
AEP_ExtractDir = $(AEP_ProjVers)
AEP_Patches    = NLS_current_apache.patch NLS_PR-3694368_mine.patch \
                 TWP_PR-4005292.patch NLS_PR-3995868.patch

#mod_ssl
mod_ssl_Project = apache_mod_ssl
AEP_mod_ssl_Project = mod_ssl
AEP_mod_ssl_Version = 2.8.22
AEP_mod_ssl_ProjVers   = $(AEP_mod_ssl_Project)-$(AEP_mod_ssl_Version)-$(AEP_Version)
AEP_mod_ssl_Filename   = $(AEP_mod_ssl_ProjVers).tar.gz
AEP_mod_ssl_ExtractDir = $(AEP_mod_ssl_ProjVers)
AEP_mod_ssl_Patches    = NLS_mod_ssl_curent.patch



ifeq ($(suffix $(AEP_Filename)),.bz2)
AEP_ExtractOption = j
else
AEP_ExtractOption = z
endif

# Extract the source.
install_source::
ifeq ($(AEP),YES)
	
	#apache stage	

	$(TAR) -C $(SRCROOT) -$(AEP_ExtractOption)xf $(SRCROOT)/$(AEP_Filename)
	$(RMDIR) $(SRCROOT)/$(AEP_Project)
	$(MV) $(SRCROOT)/$(AEP_ExtractDir) $(SRCROOT)/$(AEP_Project)
	for patchfile in $(AEP_Patches); do \
		cd $(SRCROOT)/$(Project) && patch -p0 < $(SRCROOT)/patches/$$patchfile; \
	done

	#mod_ssl stage

	$(TAR) -C $(SRCROOT) -$(AEP_ExtractOption)xf $(SRCROOT)/$(mod_ssl_Project)/$(AEP_mod_ssl_Filename)
	$(RMDIR) $(SRCROOT)/$(AEP_mod_ssl_Project)
	$(MV) $(SRCROOT)/$(AEP_mod_ssl_ExtractDir) $(SRCROOT)/$(AEP_mod_ssl_Project)
	for patchfile in $(AEP_mod_ssl_Patches); do \
		cd $(SRCROOT)/$(AEP_mod_ssl_Project) && patch -p0 < $(SRCROOT)/$(mod_ssl_Project)/$(AEP_mod_ssl_Project)_patches/$$patchfile; \
	done
	$(RMDIR) $(SRCROOT)/$(mod_ssl_Project)
	
endif


# Ignore RC_CFLAGS
Extra_CC_Flags = -DHARD_SERVER_LIMIT=2048

Environment =

# We put CFLAGS and LDFLAGS into the configure environment directly,
# and not in $(Environment), because the Apache Makefiles don't follow
# GNU guidelines, though configure mostly does.

Documentation    = $(NSDOCUMENTATIONDIR)/$(ToolType)/apache
Install_Flags    = root="$(DSTROOT)"			\
		      sysconfdir=$(ETCDIR)/httpd	\
		   Localstatedir=$(VARDIR)		\
		      runtimedir=$(VARDIR)/run		\
		      logfiledir=$(VARDIR)/log/httpd	\
		   proxycachedir=$(VARDIR)/run/proxy

Install_Target   = install
Configure_Flags  = --enable-shared=max	\
		   --enable-module=most

ifeq ($(wildcard mod_ssl),)
Configure        = cd $(shell pwd)/apache && CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(Sources)/configure
Configure_Flags += --shadow="$(BuildDirectory)"
else
Configure        = CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" "$(BuildDirectory)/configure"

# We don't want to put the EAPI patches into the source tree because we
# don't want to sift through them all the time, so lets's patch the source
# tree before each build.
Extra_CC_Flags += -DEAPI

lazy_install_source:: install-patched-source

install-patched-source:
	$(_v) if [ ! -f "$(BuildDirectory)/configure" ]; then					\
		  echo "Copying source for $(Project)...";					\
		  $(MKDIR) "$(BuildDirectory)";							\
		  (cd $(Sources) && $(PAX) -rw . "$(BuildDirectory)");				\
		  $(PAX) -rw mod_ssl "$(BuildDirectory)";					\
		  echo "Patching source (add EAPI) for $(Project)...";				\
		  (cd "$(BuildDirectory)/mod_ssl" &&						\
		  ./configure --with-apache="$(BuildDirectory)" --with-eapi-only);		\
	      fi

endif

##
# We want to compile all of the modules, so users don't have to, but
# we don't want them all turned on by default, since they add bloat
# to the server and hinder performance.
# Let's disable the ones users aren't likely to need, while leaving
# them the option of re-enabling them as desired.
# Modules listed here are disabled, except modules preceded by '-'
# are not disabled--a hack so we can keep a full list of modules here.
##
Disabled_Modules = 				\
		   vhost_alias:mod_vhost_alias	\
		   env:mod_env			\
		  -config_log:mod_log_config	\
		   mime_magic:mod_mime_magic	\
		  -mime:mod_mime		\
		  -negotiation:mod_negotiation	\
		   status:mod_status		\
		   info:mod_info		\
		  -includes:mod_include		\
		  -autoindex:mod_autoindex	\
		  -dir:mod_dir			\
		  -cgi:mod_cgi			\
		  -asis:mod_asis		\
		  -imap:mod_imap		\
		  -action:mod_actions		\
		   speling:mod_speling		\
		  -userdir:mod_userdir		\
		  -alias:mod_alias		\
		  -rewrite:mod_rewrite		\
		  -access:mod_access		\
		  -auth:mod_auth		\
		   anon_auth:mod_auth_anon	\
		   dbm_auth:mod_auth_dbm	\
		   digest:mod_digest		\
		   proxy:mod_proxy		\
		   cern_meta:mod_cern_meta	\
		   expires:mod_expires		\
		   headers:mod_headers		\
		   usertrack:mod_usertrack	\
		   unique_id:mod_unique_id	\
		  -setenvif:mod_setenvif

##
# These modules are build separately, but we want to include them in
# the default config file.
##
External_Modules = dav:libdav	\
		   ssl:libssl	\
		   perl:libperl	\
		   php4:libphp4

##
# install-local does the following:
# - Install our default doc root.
# - Install our version of printenv. (Need to resubmit to Apache.)
# - Move apache manual to documentation directory, place a symlink to it
#   in the doc root.
# - Add a symlink to the Apache release note in the doc root.
# - Make the server root group writeable.
# - Disable non-"standard" modules.
# - Add (disabled) external modules.
# - Edit the configuration defaults as needed.
# - Remove -arch foo flags from apxs since module writers may not build
#   for the same architectures(s) as we do.
# - Install manpage for checkgid(1).
##

APXS_DST = $(DSTROOT)$(USRSBINDIR)/apxs

LocalWebServer = $(NSLOCALDIR)$(NSLIBRARYSUBDIR)/WebServer
ConfigDir      = /private/etc/httpd
ProxyDir       = /private/var/run/proxy
ConfigFile     = $(ConfigDir)/httpd.conf
DocRoot        = $(LocalWebServer)/Documents
CGIDir         = $(LocalWebServer)/CGI-Executables

APXS = $(APXS_DST) -e				\
	-S SBINDIR="$(DSTROOT)$(USRSBINDIR)"	\
	-S SYSCONFDIR="$(DSTROOT)$(ConfigDir)"

install-local:
	@echo "Fixing up documents"
	$(_v) $(INSTALL_FILE) -c -m 664 "$(SRCROOT)/DocumentRoot/"*.gif "$(DSTROOT)$(DocRoot)"
	$(_v) $(INSTALL_FILE) -c -m 664 printenv "$(DSTROOT)$(CGIDir)"
	$(_v) $(MKDIR) `dirname "$(DSTROOT)$(Documentation)"`
	$(_v) $(RMDIR) "$(DSTROOT)$(Documentation)"
	$(_v) $(MV) "$(DSTROOT)$(DocRoot)/manual" "$(DSTROOT)$(Documentation)"
	$(_v) $(LN) -fs "$(Documentation)" "$(DSTROOT)$(DocRoot)/manual"
	$(_v) $(CHMOD) -R g+w "$(DSTROOT)$(DocRoot)"
	$(_v) $(CHMOD) -R g+w "$(DSTROOT)$(CGIDir)"
	$(_v) $(CHOWN) -R www.www "$(DSTROOT)$(ProxyDir)"
	@echo "Fixing up configuration"
	$(_v) perl -i -pe 's|-arch\s+\S+\s*||g' $(DSTROOT)$(USRSBINDIR)/apxs
	$(_v) $(CP) $(DSTROOT)$(ConfigFile).default $(DSTROOT)$(ConfigFile)
	$(_v) for mod in $(Disabled_Modules); do								\
		  if ! (echo $${mod} | grep -e '^-' > /dev/null); then						\
		      module=$${mod%:*};									\
		        file=$${mod#*:};									\
	              perl -i -pe 's|^(LoadModule\s+'$${module}'_module\s+)|#$${1}|' $(DSTROOT)$(ConfigFile);	\
	              perl -i -pe 's|^(AddModule\s+'$${file}'\.c)$$|#$${1}|'         $(DSTROOT)$(ConfigFile);	\
		  fi;												\
	      done
	$(_v) for mod in $(External_Modules); do	\
		  module=$${mod%:*};			\
		    file=$${mod#*:};			\
		  $(APXS) -A -n $${module} $${file}.so;	\
	      done
	$(APXS) -a -n hfs_apple mod_hfs_apple.so
	$(APXS) -a -n bonjour mod_bonjour.so
	$(_v) perl -i -pe 's|^(User\s+).*$$|$${1}www|'							$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(Group\s+).*$$|$${1}www|'							$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(MinSpareServers\s+)\d+$$|$${1}1|'					$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(MaxSpareServers\s+)\d+$$|$${1}5|'					$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(StartServers\s+)\d+$$|$${1}1|'						$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(MaxRequestsPerChild\s+)\d+$$|$${1}100000|'				$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(UserDir\s+).+$$|$${1}\"Sites\"|'						$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(ServerAdmin\s+).*$$|#$${1}webmaster\@example.com|'			$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|^(ServerName\s+).*$$|#$${1}www.example.com|'				$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|Log "(/var/log/httpd/.+)"|Log "\|/usr/sbin/rotatelogs $${1} 86400"|'	$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|/home|/Users|'								$(DSTROOT)$(ConfigFile)
	$(_v) perl -i -pe 's|public_html|Sites|'							$(DSTROOT)$(ConfigFile)
	$(_v) echo "" >>										$(DSTROOT)$(ConfigFile)
	$(_v) echo "<IfModule mod_php4.c>" >>								$(DSTROOT)$(ConfigFile)
	$(_v) echo "    # If php is turned on, we repsect .php and .phps files." >>			$(DSTROOT)$(ConfigFile)
	$(_v) echo "    AddType application/x-httpd-php .php" >>					$(DSTROOT)$(ConfigFile)
	$(_v) echo "    AddType application/x-httpd-php-source .phps" >>				$(DSTROOT)$(ConfigFile)
	$(_v) echo "" >>										$(DSTROOT)$(ConfigFile)
	$(_v) echo "    # Since most users will want index.php to work we" >>				$(DSTROOT)$(ConfigFile)
	$(_v) echo "    # also automatically enable index.php" >>					$(DSTROOT)$(ConfigFile)
	$(_v) echo "    <IfModule mod_dir.c>" >>							$(DSTROOT)$(ConfigFile)
	$(_v) echo "        DirectoryIndex index.html index.php" >>					$(DSTROOT)$(ConfigFile)
	$(_v) echo "    </IfModule>" >>									$(DSTROOT)$(ConfigFile)
	$(_v) echo "</IfModule>" >>									$(DSTROOT)$(ConfigFile)
	$(_v) echo "" >>										$(DSTROOT)$(ConfigFile)
	$(_v) echo "<IfModule mod_rewrite.c>" >>							$(DSTROOT)$(ConfigFile)
	$(_v) echo "    RewriteEngine On" >>								$(DSTROOT)$(ConfigFile)
	$(_v) echo "    RewriteCond %{REQUEST_METHOD} ^TRACE" >>					$(DSTROOT)$(ConfigFile)
	$(_v) echo "    RewriteRule .* - [F]" >>							$(DSTROOT)$(ConfigFile)
	$(_v) echo "</IfModule>" >>									$(DSTROOT)$(ConfigFile)
	$(_v) echo "" >>										$(DSTROOT)$(ConfigFile)
	$(_v) echo "<IfModule mod_bonjour.c>" >>						$(DSTROOT)$(ConfigFile)
	$(_v) echo "    # Only the pages of users who have edited their" >>				$(DSTROOT)$(ConfigFile)
	$(_v) echo "    # default home pages will be advertised on Bonjour." >>			$(DSTROOT)$(ConfigFile)
	$(_v) echo "    RegisterUserSite customized-users" >>						$(DSTROOT)$(ConfigFile)
	$(_v) echo "    #RegisterUserSite all-users" >>							$(DSTROOT)$(ConfigFile)
	$(_v) echo "" >>										$(DSTROOT)$(ConfigFile)
	$(_v) echo "    # Bonjour advertising for the primary site is off by default." >>		$(DSTROOT)$(ConfigFile)
	$(_v) echo "    #RegisterDefaultSite" >>							$(DSTROOT)$(ConfigFile)
	$(_v) echo "</IfModule>" >>									$(DSTROOT)$(ConfigFile)
	$(_v) echo "" >>										$(DSTROOT)$(ConfigFile)
	$(_v) echo "Include $(ConfigDir)/users/*.conf" >>						$(DSTROOT)$(ConfigFile)
	$(_v) $(CP)    $(DSTROOT)$(ConfigFile) $(DSTROOT)$(ConfigFile).default
	$(_v) $(RM)    $(DSTROOT)$(ConfigDir)/access.conf*
	$(_v) $(RM)    $(DSTROOT)$(ConfigDir)/srm.conf*
	$(_v) $(MKDIR) $(DSTROOT)$(ConfigDir)/users
	$(_v) perl -i -pe 's|/usr/local/apache/conf|/etc/httpd|'				$(DSTROOT)/usr/share/man/man8/httpd.8
	$(_v) perl -i -pe 's|/usr/local/apache/logs|/var/log/httpd|'				$(DSTROOT)/usr/share/man/man8/httpd.8
	$(_v) perl -i -pe 's|/var/log/httpd/httpd.pid|/var/run/httpd.pid|'			$(DSTROOT)/usr/share/man/man8/httpd.8
	$(_v) rm $(DSTROOT)/Library/WebServer/CGI-Executables/printenv
	$(_v) rm $(DSTROOT)/Library/WebServer/CGI-Executables/test-cgi
	$(_v) $(INSTALL_FILE) $(SRCROOT)/checkgid.1 \
		$(DSTROOT)/usr/share/man/man1
