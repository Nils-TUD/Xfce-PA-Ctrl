/*
 * Copyright (C) 2012, Nils Asmussen <nils@script-solution.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

using Gee;

namespace PulseAudio {
	class Device {
		public int index { get; set; }
		public string name { get; set; }
		public string nice_name { get; set; }
		public int volume { get; set; }
		public bool is_default { get; set; }
		public bool is_muted { get; set; }
		public int relative_volume {
			get {
				return (int)(100 * ((double)volume / 0x10000));
			}
			internal set {
				volume = (value * 0x10000) / 100;
			}
		}
	}
	
	errordomain Error {
		DUMP_PARSING_FAILED,
		SET_VOLUME_FAILED,
		SET_MUTE_FAILED,
		SET_DEFAULT_FAILED,
		NO_DEFAULT_DEVICE
	}
	
	class DeviceContainer {
		public DeviceContainer() throws Error {
			parse_dump();
		}
		
		public Iterator<Device> iterator() {
			return devices.iterator();
		}
		
		public Device default_device() throws Error {
			foreach(Device dev in devices) {
				if(dev.is_default)
					return dev;
			}
			throw new Error.NO_DEFAULT_DEVICE("No default device found");
		}
		
		public void set_default(Device dev) throws Error {
			foreach(Device d in devices) {
				if(d == dev) {
					d.is_default = true;
					try {
		                // set default sink
						Process.spawn_command_line_sync(
							"pacmd set-default-sink " + d.index.to_string()
						);
						
						// move all currently playing stuff to the new default sink
						string output;
						Process.spawn_command_line_sync("pacmd list-sink-inputs", out output);
						int counter = 0;
						var inputs = new int[devices.size];
						foreach(string line in output.split("\n")) {
							if("index:" in line)
								inputs[counter++] = int.parse(line.split(": ")[1]);
						}
						for(int i = 0; i < counter; ++i) {
							Process.spawn_command_line_sync(
								"pacmd move-sink-input " + inputs[i].to_string() + " " + d.index.to_string()
							);
						}
					}
					catch(SpawnError e) {
						throw new Error.SET_DEFAULT_FAILED(e.message);
					}
				}
				else
					d.is_default = false;
			}
		}
		
		public void set_volume(Device dev, int percent) throws Error {
			try {
				dev.relative_volume = percent;
				Process.spawn_command_line_sync(
					"pacmd set-sink-volume " + dev.index.to_string() + " %#x".printf(dev.volume)
				);
			}
			catch(SpawnError e) {
				throw new Error.SET_VOLUME_FAILED(e.message);
			}
		}
		
		public void set_muted(Device dev, bool muted) throws Error {
			try {
				dev.is_muted = muted;
				Process.spawn_command_line_sync(
					"pacmd set-sink-mute " + dev.index.to_string() + " " + (dev.is_muted ? "yes" : "no")
				);
			}
			catch(SpawnError e) {
				throw new Error.SET_MUTE_FAILED(e.message);
			}
		}
		
		private void parse_dump() throws Error {
			devices = new ArrayList<Device>();
			try {
				string dump;
				Process.spawn_command_line_sync("pacmd dump", out dump);
			
				string[] lines = dump.split("\n");
				foreach(string line in lines) {
					if("device_id=" in line)
						add_device(line);
					else
						set_device_attr(line);
				}
				change_names();
			}
			catch(SpawnError e) {
				throw new Error.DUMP_PARSING_FAILED(e.message);
			}
			catch(RegexError e) {
				throw new Error.DUMP_PARSING_FAILED(e.message);
			}
		}
		
		private void add_device(string line) throws RegexError {
			var dev = new Device();
			Regex pattern_devid	= new Regex("device_id=\"(\\d+)\"");
			Regex pattern_name	= new Regex("name=\"(.*?)\"");
			string[] parts = line.split(" ");
			foreach(string part in parts) {
				MatchInfo info;
				if(pattern_devid.match(part, 0, out info))
					dev.index = int.parse(info.fetch(1));
				else if(pattern_name.match(part, 0, out info))
					dev.name = info.fetch(1).replace("alsa_card.", "");
			}
			devices.add(dev);
		}
		
		private void set_device_attr(string line) {
			foreach(Device dev in devices) {
				if(dev.name in line) {
					string cmd = line.split(" ")[0];
					if(cmd == "set-default-sink")
						dev.is_default = true;
					else if(cmd == "set-sink-volume")
						dev.volume = (int)line.split(" ")[2].to_long(null, 16);
					else if(cmd == "set-sink-mute")
						dev.is_muted = line.split(" ")[2] == "yes";
				}
			}
		}
		
		private void change_names() throws SpawnError, RegexError {
			string cards;
			Process.spawn_command_line_sync("pacmd list-cards", out cards);
		
			Device? dev = null;
			int index = -1;
			Regex idxregex		= new Regex("\\s*index:\\s*(\\d+)");
			Regex vendorregex	= new Regex("\\s*device.vendor.name = \"(.*?)\"");
			Regex prodregex		= new Regex("\\s*device.product.name = \"(.*?)\"");
			string[] lines = cards.split("\n");
			foreach(string line in lines) {
				MatchInfo info;
				if(idxregex.match(line, 0, out info)) {
					index = int.parse(info.fetch(1));
					dev = get_by_index(index);
				}
				else if(dev != null) {
					if(vendorregex.match(line, 0, out info))
						dev.nice_name = info.fetch(1);
					else if(prodregex.match(line, 0, out info))
						dev.nice_name += " " + info.fetch(1);
				}
			}
		}
		
		private Device? get_by_index(int index) {
			foreach(Device dev in devices) {
				if(dev.index == index)
					return dev;
			}
			return null;
		}
		
		private ArrayList<Device> devices;
	}
}

