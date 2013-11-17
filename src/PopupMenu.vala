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

using MyPulseAudio;
using Gtk;

namespace UI {
	class StreamVBox : Gtk.VBox {
		private Label label;
		private HBox hbox;
		private VBox vbox;
		private HScale volume;
		private CheckButton muted;
		private StreamContainer streams;
		public Stream default_stream {
			get; private set;
		}
        public signal void volume_changed();

		public StreamVBox(StreamContainer streams) {
			set_homogeneous(false);
			set_spacing(2);
			set_border_width(2);

			this.streams = streams;
			this.default_stream = streams.get_default();

			// add widgets
			this.vbox = new VBox(true, 2);
			add_streams();
			pack_start(this.vbox, true, true, 2);

			pack_start(new HSeparator(), false, false, 2);

			this.hbox = new HBox(false, 2);
			add_mute();
			add_volume();
			pack_start(this.hbox, false, false, 2);

			// set widgets for default device
			set_for_default();
		}

		private void add_streams() {
			unowned SList<RadioButton> group = null;
			foreach(Stream str in streams) {
				var item = new RadioButton.with_label(group, str.nice_name);
				item.set_active(str.is_default);
				item.toggled.connect(() => {
					try {
						if(item.active) {
							streams.set_default(str);
							default_stream = str;
							set_for_default();
						}
					}
					catch(MyPulseAudio.Error e) {
						stderr.printf("Error: %s\n", e.message);
					}
				});
				vbox.add(item);
				group = item.get_group();
			}
		}

		private void add_mute() {
			muted = new CheckButton();
			muted.toggled.connect(() => {
				try {
					streams.set_muted(default_stream, muted.active);
					volume_changed();
				}
				catch(MyPulseAudio.Error e) {
					stderr.printf("Error: %s\n", e.message);
				}
			});
			hbox.pack_start(muted, false, false, 2);
		}

		private void add_volume() {
			volume = new HScale.with_range(0, 100, 1);
			volume.draw_value = false;
			volume.change_value.connect((scroll, new_value) => {
				if(new_value >= 0 && new_value <= 100) {
					try {
						streams.set_volume(default_stream, (int)new_value);
						volume_changed();
					}
					catch(MyPulseAudio.Error e) {
						stderr.printf("Error: %s\n", e.message);
					}
					return false;
				}
				return true;
			});
			hbox.pack_start(volume, true, true, 2);
		}

		private void set_for_default() {
			volume.set_value(default_stream.relative_volume);
			muted.active = default_stream.is_muted;
			volume_changed();
		}
	}

	class PopupMenu : Gtk.Window {
        private StreamVBox sinksvbox;

        public signal void output_changed();
        public Stream default_output {
        	get {
        		return sinksvbox.default_stream;
        	}
        }

		public PopupMenu(StreamContainer sources,StreamContainer sinks) throws MyPulseAudio.Error {
			// use a frame to have a border
			Frame frm = new Frame(null);
			// put input and output in separate tabs
			// output is more important and thus visible by default
			Gtk.Notebook nb = new Gtk.Notebook();
			sinksvbox = new StreamVBox(sinks);
			sinksvbox.volume_changed.connect(() => {
				output_changed();
			});
			nb.append_page(sinksvbox, new Gtk.Label("Output"));
			nb.append_page(new StreamVBox(sources), new Gtk.Label("Input"));
			frm.add(nb);
			add(frm);

			// set some window attributes to make it look like a popup
			set_resizable(false);
			set_decorated(false);
			set_skip_taskbar_hint(true);
			set_skip_pager_hint(true);
			{
				// use background color of a popup-menu
				Gtk.Menu menu = new Gtk.Menu();
				menu.realize();
				modify_bg(StateType.NORMAL, menu.get_style().bg[0]);
			}
		}
	}
}

