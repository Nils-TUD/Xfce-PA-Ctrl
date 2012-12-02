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

namespace UI {
	class PulseAudioPlugin : Xfce.PanelPlugin {
		public override void @construct() {
			button = new Button();
			button.clicked.connect(() => {
				if(menu.visible)
					menu.hide();
				else {
					menu.realize();
					menu.show_all();
					int x, y;
					position_func(menu, out x, out y);
					menu.move(x, y);
				}
			});
			add(button);
			button.show();
			add_action_widget(button);
			
			try {
				menu = new PopupMenu(button);
			}
			catch(PulseAudio.Error e) {
				stderr.printf("Error: %s\n", e.message);
			}
			
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

		private void position_func(Widget widget, out int x, out int y) {
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
		
		private PopupMenu? menu;
		private Button button;
	}
}

[ModuleInit]
public Type xfce_panel_module_init(TypeModule module) {
	return typeof(UI.PulseAudioPlugin);
}

