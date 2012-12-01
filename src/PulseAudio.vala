using Gee;

namespace PulseAudio {
	class Device {
		public int index { get; set; }
		public string name { get; set; }
		public int volume { get; set; }
		public bool is_default { get; set; }
		public bool is_muted { get; set; }
	}
	
	errordomain DumpError {
		PARSING_FAILED
	}
	
	class DeviceContainer {
		public DeviceContainer() throws DumpError {
			parse_dump();
		}
		
		public Iterator<Device> iterator() {
			return devices.iterator();
		}
		
		public void set_volume_relative(int inc) {
			foreach(Device dev in devices) {
				dev.volume = int.max(0, int.min(0x10000, dev.volume + inc));
				set_volume(dev);
			}
		}
		
		private void set_volume(Device d) {
			try {
				Process.spawn_command_line_sync(
					"pacmd set-sink-volume " + d.index.to_string() + "%#x".printf(d.volume)
				);
			}
			catch(SpawnError e) {
				stderr.printf("Error: %s\n", e.message);
			}
		}
		
		private void parse_dump() throws DumpError {
			devices = new ArrayList<Device>();
			try {
				Regex pattern_devid = new Regex("device_id=\"(\\d+)\"");
				Regex pattern_name = new Regex("name=\"(.*?)\"");
			
				string dump;
				Process.spawn_command_line_sync("pacmd dump", out dump);
			
				string[] lines = dump.split("\n");
				foreach(string line in lines) {
					if("device_id=" in line) {
						var dev = new Device();
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
					else {
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
				}
			}
			catch(Error e) {
				throw new DumpError.PARSING_FAILED(e.message);
			}
		}
		
		private ArrayList<Device> devices;
	}
}

