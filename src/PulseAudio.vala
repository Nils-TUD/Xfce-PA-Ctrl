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
				volume = (int)(value * 0x10000 / 100.0);
			}
		}
	}
	
	public errordomain Error {
		DUMP_PARSING_FAILED,
		NO_PCI_DEVICE,
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
		
		public void set_volume(int percent) throws Error {
			foreach(Device dev in devices) {
				dev.relative_volume = percent;
				set_volume_of(dev);
			}
		}
		
		public void toggle_muted() throws Error {
			foreach(Device dev in devices) {
				dev.is_muted = !dev.is_muted;
				set_muted_of(dev);
			}
		}
		
		private void set_volume_of(Device d) throws Error {
			try {
				Process.spawn_command_line_sync(
					"pacmd set-sink-volume " + d.index.to_string() + "%#x".printf(d.volume)
				);
			}
			catch(SpawnError e) {
				throw new Error.SET_VOLUME_FAILED(e.message);
			}
		}
		
		private void set_muted_of(Device d) throws Error {
			try {
				Process.spawn_command_line_sync(
					"pacmd set-sink-mute " + d.index.to_string() + " " + (d.is_muted ? "yes" : "no")
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
			Regex pattern_devid = new Regex("device_id=\"(\\d+)\"");
			Regex pattern_name = new Regex("name=\"(.*?)\"");
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
		
		private void change_names() {
			foreach(Device dev in devices) {
				try {
					if(dev.name[0:4] == "pci-") {
						Regex pattern = new Regex("\\d+_(\\d+)_(\\d+).(\\d+).*");
						MatchInfo info;
						if(pattern.match(dev.name, 0, out info)) {
							PCI.BDF bdf = {
								int.parse(info.fetch(1)),
								int.parse(info.fetch(2)),
								int.parse(info.fetch(3))
							};
							dev.nice_name = PCI.bdf_to_name(bdf);
						}
					}
					else if(dev.name[0:4] == "usb-")
						dev.nice_name = dev.name.substring(dev.name.index_of_char('_') + 1);
				}
				catch(RegexError e) {
					stderr.printf("Error: %s\n", e.message);
				}
				catch(Error e) {
					dev.nice_name = dev.name;
				}
			}
		}
		
		private ArrayList<Device> devices;
	}
}

