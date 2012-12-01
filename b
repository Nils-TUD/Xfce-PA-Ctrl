#!/bin/sh

# config
# TODO required because of a scons-bug? (dependency cycle for no real reason)
#if [ -f /proc/cpuinfo ]; then
#    cpus=`cat /proc/cpuinfo | grep '^processor[[:space:]]*:' | wc -l`
#else
    cpus=1
#fi
opts="-j$cpus"

# fall back to some reasonable defaults for the RPC environment variables
if [ "$XPC_BUILD" != "debug" ]; then
    export XPC_BUILD="release"
fi

# don't change anything below!
build="build/$XPC_BUILD"

echo "Building for $XPC_BUILD mode with $cpus jobs..."

cmd=$1
if [ "$cmd" != "install" ] && [ "$cmd" != "uninstall" ]; then
    scons $opts || exit 1
else
    scons $opts $cmd || exit 1
fi

# run the specified command, if any
case "$cmd" in
    clean)
        scons -c
        ;;
    distclean)
        rm -Rf build/*
        ;;
    run)
        killall xfce4-panel
        xfce4-panel &
        ;;
    dis)
        objdump -SC $build/bin/xfce-pa-ctrl | less
        ;;
    elf)
        readelf -a $build/bin/xfce-pa-ctrl | less
        ;;
esac
