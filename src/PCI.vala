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
