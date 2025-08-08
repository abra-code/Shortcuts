#! /bin/sh

echo "\n--------------------------------------------------------------------"
echo "Starting Shortcuts Build"

IN_CONFIG=$1;
IN_ACTION=$2;

PARENT_DIR=`dirname "$0"`;
cd "$PARENT_DIR";
echo "`pwd`";

if test "$IN_CONFIG" == ""; then
	IN_CONFIG="ship";
fi

if test "$IN_ACTION" == ""; then
	IN_ACTION="build";
fi

if test $IN_CONFIG == debug; then
	BUILD_CONFIG="Development";
else
	BUILD_CONFIG="Deployment";
fi

xcodebuild -project ShortcutObserver/ShortcutObserver.xcodeproj -alltargets -configuration $BUILD_CONFIG $IN_ACTION;
echo "\n"

xcodebuild -project Shortcuts.xcodeproj -alltargets -configuration $BUILD_CONFIG $IN_ACTION;
echo "\n"
