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

namespace MyPulseAudio {
	class Stream {
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

	public enum StreamType {
		SINK,
		SOURCE
	}

	errordomain Error {
		DUMP_PARSING_FAILED,
		SET_VOLUME_FAILED,
		SET_MUTE_FAILED,
		SET_DEFAULT_FAILED,
		NO_DEFAULT_STREAM
	}

	class StreamContainer {
		private ArrayList<Stream> streams = new ArrayList<Stream>();
		public StreamType streamType {
			get; internal set;
		}

		public StreamContainer(StreamType type) throws Error {
			this.streamType = type;
			parse();
		}

		public Iterator<Stream> iterator() {
			return streams.iterator();
		}

		public Stream get_default() throws Error {
			Stream d = get_default_stream();
			if(d == null)
				throw new Error.NO_DEFAULT_STREAM("No default stream found");
			return d;
		}

		public void set_default(Stream str) throws Error {
			string setcmd = "set-default-" + (streamType == StreamType.SINK ? "sink" : "source");
			string lstcmd = "list-" + (streamType == StreamType.SINK ? "sink-inputs" : "source-outputs");
			string mvecmd = "move-" + (streamType == StreamType.SINK ? "sink-input" : "source-output");
			foreach(Stream s in streams) {
				if(s == str) {
					s.is_default = true;
					try {
		                // set default stream
						Process.spawn_command_line_sync(
							"pacmd " + setcmd + " " + s.index.to_string()
						);

						// move all currently playing stuff to the new default stream
						string output;
						Process.spawn_command_line_sync("pacmd " + lstcmd, out output);
						int counter = 0;
						var inputs = new int[streams.size];
						foreach(string line in output.split("\n")) {
							if("index:" in line)
								inputs[counter++] = int.parse(line.split(": ")[1]);
						}
						for(int i = 0; i < counter; ++i) {
							Process.spawn_command_line_sync(
								"pacmd " + mvecmd + " " + inputs[i].to_string() + " " + s.index.to_string()
							);
						}
					}
					catch(SpawnError e) {
						throw new Error.SET_DEFAULT_FAILED(e.message);
					}
				}
				else
					s.is_default = false;
			}
		}

		public void set_volume(Stream str, int percent) throws Error {
			string setcmd = "set-" + (streamType == StreamType.SINK ? "sink" : "source") + "-volume";
			try {
				str.relative_volume = percent;
				Process.spawn_command_line_sync(
					"pacmd " + setcmd + " " + str.index.to_string() + " %#x".printf(str.volume)
				);
			}
			catch(SpawnError e) {
				throw new Error.SET_VOLUME_FAILED(e.message);
			}
		}

		public void set_muted(Stream str, bool muted) throws Error {
			string setcmd = "set-" + (streamType == StreamType.SINK ? "sink" : "source") + "-mute";
			try {
				str.is_muted = muted;
				Process.spawn_command_line_sync(
					"pacmd " + setcmd + " " + str.index.to_string() + " " + (str.is_muted ? "yes" : "no")
				);
			}
			catch(SpawnError e) {
				throw new Error.SET_MUTE_FAILED(e.message);
			}
		}

		private void parse() throws Error {
			string lstcmd = "list-" + (streamType == StreamType.SINK ? "sinks" : "sources");
			streams.clear();
			try {
				Regex pattern_index		= new Regex("\\s*(\\*)?\\s*index: (\\d+)");
				Regex pattern_name		= new Regex("\\s*name: <(.*?)>");
				Regex pattern_desc		= new Regex("\\s*device.description = \"(.*?)\"");
				Regex pattern_vol		= new Regex("\\s*volume: front-left:\\s*\\d+\\s*/\\s*(\\d+)%");
				Regex pattern_muted		= new Regex("\\s*muted: (no|yes)");
				string dump;
				Process.spawn_command_line_sync("pacmd " + lstcmd, out dump);

				Stream? str = null;
				string[] lines = dump.split("\n");
				foreach(string line in lines) {
					MatchInfo info;
					if("index: " in line) {
						if(str != null)
							streams.add(str);

						pattern_index.match(line, 0, out info);
						int index = int.parse(info.fetch(2));
						str = new Stream();
						str.index = index;
						str.is_default = info.fetch(1) != "";
					}
					else if(str != null) {
						if(pattern_name.match(line, 0, out info))
							str.name = info.fetch(1);
						else if(pattern_vol.match(line, 0, out info))
							str.relative_volume = int.parse(info.fetch(1));
						else if(pattern_muted.match(line, 0, out info))
							str.is_muted = info.fetch(1) == "yes";
						else if(pattern_desc.match(line, 0, out info))
							str.nice_name = info.fetch(1);
					}
				}

				if(str != null)
					streams.add(str);
			}
			catch(SpawnError e) {
				throw new Error.DUMP_PARSING_FAILED(e.message);
			}
			catch(RegexError e) {
				throw new Error.DUMP_PARSING_FAILED(e.message);
			}
		}

		private Stream? get_default_stream() {
			foreach(Stream s in streams) {
				if(s.is_default)
					return s;
			}
			return null;
		}
	}
}

