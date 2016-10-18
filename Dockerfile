FROM dock0/pkgforge
RUN pacman -S --noconfirm --needed opensp docbook-utils
