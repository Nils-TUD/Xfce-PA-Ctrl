namespace PCI {
	struct BDF {
		public int bus { get; set; }
		public int dev { get; set; }
		public int func { get; set; }
	}

	string bdf_to_name(BDF bdf) {
		try {
			string output;
			Process.spawn_command_line_sync(
				"lspci -s %02d:%02d.%d".printf(bdf.bus, bdf.dev, bdf.func),
				out output
			);
			Regex pattern = new Regex("\\d+:\\d+\\.\\d+ .*?: (.*?) \\(rev .*?\\)\\s*");
			MatchInfo info;
			if(pattern.match(output, 0, out info))
				return info.fetch(1);
		}
		catch(Error e) {
		}
		return "Unknown";
	}
}
