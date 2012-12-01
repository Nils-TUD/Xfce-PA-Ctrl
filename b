#!/bin/sh

# config
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
root=$(dirname $(readlink -f $0))

# parse arguments
dobuild=true
cmd=""
script=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|-\?|--help)
            help $0
            ;;

        -n|--no-build)
            dobuild=false
            ;;

        *)
            if [ "$cmd" = "" ]; then
                cmd="$1"
            elif [ "$script" = "" ]; then
                script="$1"
            else
                echo "Too many arguments" >&2
                exit 1
            fi
            ;;
    esac
    shift
done

binary=""
case "$cmd" in
    # for clean and distclean, it makes no sense to build it (this might even fail because e.g. scons has
    # a non existing dependency which might be the reason the user wants to do a clean)
    clean|distclean)
        dobuild=false
        ;;
    run|dis|elf|straddr|dbg)
        ;;
    ?*)
        echo "Unknown command '$cmd'" >&2
        exit 1
        ;;
esac

echo "Working in $XPC_BUILD mode"

if $dobuild; then
    echo "Building with $cpus jobs..."

    # build userland
    scons $opts || exit 1
    sudo cp $build/bin/libxfce-pa-ctrl.so /usr/lib/xfce4/panel/plugins
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
    straddr)
        echo "Strings containing '$script' in $binary:"
        # find base address of .rodata
        base=`readelf -S $build/bin/xfce-pa-ctrl | grep .rodata | \
            xargs | cut -d ' ' -f 5`
        # grep for matching lines, prepare for better use of awk and finally add offset to base
        readelf -p 4 $build/bin/$binary | grep $script | \
            sed 's/^ *\[ *\([[:xdigit:]]*\)\] *\(.*\)$/0x\1 \2/' | \
            awk '{ printf("0x%x: %s %s %s %s %s %s\n",0x'$base' + strtonum($1),$2,$3,$4,$5,$6,$7) }'
        ;;
    dbg)
        tmp=$(mktemp)
        echo "display/i \$pc" >> $tmp
        gdb -tui $build/bin/xfce-pa-ctrl --command=$tmp
        rm -f $tmp
        ;;
esac
