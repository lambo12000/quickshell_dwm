# qs-screensaver-helper - org.freedesktop.ScreenSaver inhibit sink
# See LICENSE file for copyright and license details.

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
PKG_CFLAGS != pkg-config --cflags libsystemd
PKG_LIBS   != pkg-config --libs libsystemd

all: qs-screensaver-helper

qs-screensaver-helper: qs-screensaver-helper.c
	$(CC) $(CFLAGS) $(PKG_CFLAGS) -o $@ qs-screensaver-helper.c $(PKG_LIBS)

clean:
	rm -f qs-screensaver-helper

.PHONY: all clean
