#!/bin/sh
# Restricted fork intentionally does not build, install, or inspect the phone.
printf '%s\n' 'Automatic installation is disabled for this experimental fork.' 'Review README.md; approve a source build and offline tests before use.' >&2
exit 2
