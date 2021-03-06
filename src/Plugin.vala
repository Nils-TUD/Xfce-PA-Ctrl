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

using Xfce;
using Gee;
using Gtk;
using MyPulseAudio;
using PulseAudio;

namespace UI {
	class PulseAudioPlugin : Xfce.PanelPlugin {
		private enum IconType {
			MUTED	= 0,
			LOW		= 1,
			MEDIUM	= 2,
			HIGH	= 3
		}

		private ToggleButton button;
		private Image? images[4];
		private string icons[4];
		private PopupMenu menu;

		public void subscribe_event(Context c, Context.SubscriptionEventType t, uint32 idx) {
			print("event: %d : %u\n", t, idx);
		}

		public override void @construct() {
			PulseAudio.GLibMainLoop loop = new PulseAudio.GLibMainLoop();
			Context con = new Context(loop.get_api(), null);
            con.set_subscribe_callback(this.subscribe_event);
            con.subscribe(Context.SubscriptionMask.ALL);

            // Connect the context
            if(con.connect(null, Context.Flags.NOFAIL, null) < 0) {
                print( "pa_context_connect() failed: %s\n", PulseAudio.strerror(con.errno()));
            }

			// images for the panel-button
			icons[IconType.MUTED]	= "audio-volume-muted";
			icons[IconType.LOW]		= "audio-volume-low";
			icons[IconType.MEDIUM]	= "audio-volume-medium";
			icons[IconType.HIGH]	= "audio-volume-high";

			button = new ToggleButton();
			button.clicked.connect(() => {
				if(menu.visible)
					menu.hide();
				else {
					try {
						menu = new PopupMenu(new StreamContainer(StreamType.SOURCE),
							new StreamContainer(StreamType.SINK));
						// close popup if it looses focus
						menu.set_events(Gdk.EventMask.FOCUS_CHANGE_MASK);
						menu.focus_out_event.connect((event) => {
							button.active = false;
							menu.hide();
							return true;
						});

						// change button icon when the volume or muted state changed
						menu.output_changed.connect(() => {
							adjust_button_icon(menu.default_output);
						});

						menu.realize();
						menu.show_all();
						int x, y;
						get_popup_position(menu, out x, out y);
						menu.move(x, y);
					}
					catch(MyPulseAudio.Error e) {
						stderr.printf("Error: %s\n", e.message);
					}
				}
			});
			add(button);
			button.show();
			add_action_widget(button);

			size_changed.connect((size) => {
				StreamContainer sinks = new StreamContainer(StreamType.SINK);
				// calculate the matching icon again, based on the new size
				for(int i = 0; i < images.length; ++i)
					images[i] = null;
				adjust_button_icon(sinks.get_default());
				return true;
			});

			menu_show_about();
			about.connect(() => {
				show_about_dialog(
					null,
					"program-name", "Pulse Audio Control",
					"comments", "Let's you choose the device, control the volume and mute/unmute devices",
					null
				);
			});

			destroy.connect(() => {
				main_quit();
			});
		}

		private void adjust_button_icon(MyPulseAudio.Stream str) {
			if(str.is_muted)
				set_button_icon(IconType.MUTED);
			else if(str.relative_volume <= 33)
				set_button_icon(IconType.LOW);
			else if(str.relative_volume <= 66)
				set_button_icon(IconType.MEDIUM);
			else
				set_button_icon(IconType.HIGH);
		}

		private void set_button_icon(IconType type) {
			if(images[type] == null) {
				// find the best matching item, based on the panel size
				IconInfo info = IconTheme.get_default().lookup_icon(
					icons[type], get_size(), IconLookupFlags.USE_BUILTIN
				);
				try {
					images[type] = new Image.from_pixbuf(info.load_icon());
				}
				catch(GLib.Error e) {
					images[type] = new Image.from_icon_name(icons[type], IconSize.BUTTON);
				}
			}
			button.set_image(images[type]);
		}

		private void get_popup_position(Widget widget, out int x, out int y) {
			int width = button.allocation.width;
			int height = button.allocation.height;

			// get panel-plugin position
			Requisition req;
			widget.size_request(out req);
			button.get_window().get_origin(out x, out y);

			// get rectangle of the monitor the panel-plugin is on
			Gdk.Rectangle monrect;
			Gdk.Screen screen = Gdk.Screen.get_default();
			int monitor = screen.get_monitor_at_point(x, y);
			screen.get_monitor_geometry(monitor, out monrect);

			switch(get_orientation()) {
				case Orientation.HORIZONTAL:
					// Show menu above
					if(y + height + req.height > monrect.height)
						y -= req.height;
					// Show menu below
					else
						y += height;

					// Adjust horizontal position
					if(x + req.width > monrect.width)
						x = monrect.width - req.width;
					break;

				case Orientation.VERTICAL:
					// show menu on the right
					if(x + width + req.width > monrect.width)
						x -= req.width;
					// show menu on the left
					else
						x += width;

					if(y + req.height > monrect.height)
						y = monrect.height - req.height;
					break;
			}
		}
	}
}

[ModuleInit]
public Type xfce_panel_module_init(TypeModule module) {
	return typeof(UI.PulseAudioPlugin);
}

