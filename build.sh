#!/bin/bash
gmake clean
gmake JAILED=1

cp -v .theos/obj/debug/muffinsync.dylib muffinsync.dylib
install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate muffinsync.dylib
ldid -S muffinsync.dylib
