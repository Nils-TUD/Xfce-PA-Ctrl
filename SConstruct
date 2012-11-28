import os

env = Environment(
    CC = 'clang',
    CFLAGS = '-Wall -Wextra -ansi -std=c99',
    CPPPATH = '#include',
    ENV = {
        'PATH' : os.environ['PATH'],
        'TERM' : os.environ['TERM'],
        'HOME' : os.environ['HOME'],
    },
)

btype = os.environ.get('XPC_BUILD')
if btype == 'debug':
    env.Append(CFLAGS = ' -O0 -ggdb')
else:
    env.Append(CFLAGS = ' -O3 -DNDEBUG')
    btype = 'release'
builddir = 'build/' + btype

verbose = ARGUMENTS.get('VERBOSE',0);
if int(verbose) == 0:
    env['CCCOMSTR'] = "CC $TARGET"
    env['LINKCOMSTR'] = "LD $TARGET"

env.Append(
    BUILDDIR = '#' + builddir,
    BINARYDIR = '#' + builddir + '/bin',
)

env.SConscript('src/SConscript', 'env', variant_dir = builddir + '/src', duplicate = 0)
