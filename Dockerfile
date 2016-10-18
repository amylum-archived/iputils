FROM dock0/pkgforge
RUN pacman -S --noconfirm --needed opensp docbook-utils perl-sgmls
RUN ln -s /usr/bin/vendor_perl/sgmlspl.pl /usr/local/bin/sgmlspl
