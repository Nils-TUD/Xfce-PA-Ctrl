import os, subprocess

flags = subprocess.check_output(['pkg-config', '--cflags', 'libxfce4panel-1.0 gee-1.0']).rstrip()
libs = subprocess.check_output(['pkg-config', '--libs', 'libxfce4panel-1.0 gee-1.0']).rstrip()

vala_builder = Builder(action = '$VC -d $BUILDDIR_OS -C $VCFLAGS $SOURCES',
                       src_suffix = '.vala')
env = Environment(
    PREFIX = '/usr',
    CC = 'clang',
    VC = 'valac',
    VCFLAGS = '--pkg=gtk+-2.0 --pkg=gee-1.0 --pkg=libxfce4panel-1.0',
    CFLAGS = '-ansi -std=c99 ' + flags,
    LINKFLAGS = libs,
    ENV = {
        'PATH' : os.environ['PATH'],
        'TERM' : os.environ['TERM'],
        'HOME' : os.environ['HOME'],
    },
    BUILDERS = {'Vala' : vala_builder}
)

btype = os.environ.get('XPC_BUILD')
if btype == 'debug':
    env.Append(CFLAGS = ' -O0 -ggdb')
    env.Append(VCFLAGS = ' -g')
else:
    env.Append(CFLAGS = ' -O3 -DNDEBUG')
    btype = 'release'
builddir = 'build/' + btype

env.Append(
    BUILDDIR = '#' + builddir,
    BUILDDIR_OS = builddir,
    BINARYDIR = '#' + builddir + '/bin',
)

env.SConscript('dist/SConscript', 'env', variant_dir = builddir + '/dist', duplicate = 0)
env.SConscript('src/SConscript', 'env', variant_dir = builddir + '/src', duplicate = 0)

if 'uninstall' in COMMAND_LINE_TARGETS:
	env.Command("uninstall", None, Delete(FindInstalledFiles()))
