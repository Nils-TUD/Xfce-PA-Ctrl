#!/usr/bin/env python

import os
import sys
import subprocess
import StringIO
import re

class PulseAudioCtrl(object):
    def __init__(self):
        self.devices = []
        lines = StringIO.StringIO(subprocess.check_output(["pacmd", "dump"]))
        for line in lines:
            if "device_id=" in line:
                device = {
                    'idx' : 0,
                    'name' : '',
                    'default' : False,
                    'volume' : 0,
                    'muted' : 'no'
                }
                for x in line.split(' '):
                    m = re.match(r'device_id="([0-9]+)"', x)
                    if m != None:
                        device['idx'] = m.groups()[0]
                        continue
                    m = re.match(r'name="(.*?)"', x)
                    if m != None:
                        device['name'] = m.groups()[0]
                        continue
                self.devices.append(device)
            else:
                for d in self.devices:
                    if d['name'] in line:
                        cmd = line.split(' ')[0]
                        if cmd == 'set-default-sink':
                            d['default'] = True
                        elif cmd == 'set-sink-volume':
                            d['volume'] = int(line.split(' ')[2], 16)
                        elif cmd == 'set-sink-mute':
                            d['muted'] = line.split(' ')[2].rstrip()

    def set_volume_relative(self, inc):
        for d in self.devices:
            d['volume'] = max(0, min(0x10000, int(d['volume']) + inc))
            self._set_volume(d)

    def set_volume_absolute(self, vol):
        for d in self.devices:
            d['volume'] = vol * 0x10000 / 100
            self._set_volume(d)
    
    def _set_volume(self, d):
            subprocess.call(['pacmd', 'set-sink-volume', d['idx'], "%#x" % d['volume']])

    def toggle_mute(self):
        for d in self.devices:
            if d['muted'] == 'no':
                d['muted'] = 'yes'
            else:
                d['muted'] = 'no'
            subprocess.call(['pacmd', 'set-sink-mute', d['idx'], d['muted']])

    def set_default(self, idx):
        for d in self.devices:
            if int(d['idx']) == idx:
                d['default'] = True
                # set default sink
                subprocess.call(['pacmd', 'set-default-sink', d['idx']])
                # move all currently playing stuff to the new default sink
                lines = StringIO.StringIO(subprocess.check_output(["pacmd", "list-sink-inputs"]))
                counter = 0
                inputs = {}
                for line in lines:
                    if "index:" in line:
                        inputs[counter] = int(line.split(': ')[1].rstrip(), 10)
                        counter += 1
                count = 0
                while count < counter:
                    subprocess.call(['pacmd', 'move-sink-input', str(inputs[count]), d['idx']])
                    count += 1
            else:
                d['default'] = False

pac = PulseAudioCtrl()
pac.set_default(int(sys.argv[1]))
print pac.devices
#pac.set_volume_absolute(10)

