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

using PulseAudio;
using Gtk;

namespace UI {
	public class PopupMenu : Gtk.Window {
		private enum Icons {
			MUTED	= 0,
			LOW		= 1,
			MEDIUM	= 2,
			HIGH	= 3
		}
	
		public PopupMenu(Button btn) throws PulseAudio.Error {
			// images for the panel-button
			images[Icons.MUTED]		= new Image.from_icon_name("audio-volume-muted", IconSize.BUTTON);
			images[Icons.LOW]		= new Image.from_icon_name("audio-volume-low", IconSize.BUTTON);
			images[Icons.MEDIUM]	= new Image.from_icon_name("audio-volume-medium", IconSize.BUTTON);
			images[Icons.HIGH]		= new Image.from_icon_name("audio-volume-high", IconSize.BUTTON);
			button = btn;
			
			// use a frame to have a border
			frm = new Frame(null);
			vbox = new VBox(true, 2);
			vbox.set_border_width(2);
			frm.add(vbox);
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
			// close popup if it looses focus
			set_events(Gdk.EventMask.FOCUS_CHANGE_MASK);
			focus_out_event.connect((event) => {
				this.hide();
				return true;
			});
			
			// get audio device list
			devices = new DeviceContainer();
			default_device = devices.default_device();
		
			// add widgets
			add_devices();
			vbox.add(new HSeparator());
			add_mute();
			add_volume();
			
			// set widgets for default device
			set_for_default();
		}
	
		private void add_devices() {
			unowned SList<RadioButton> group = null;
			foreach(Device dev in devices) {
				var item = new RadioButton.with_label(group, dev.nice_name);
				item.set_active(dev.is_default);
				item.toggled.connect(() => {
					try {
						if(item.active) {
							devices.set_default(dev);
							default_device = dev;
							set_for_default();
						}
					}
					catch(PulseAudio.Error e) {
						stderr.printf("Error: %s\n", e.message);
					}
				});
				vbox.add(item);
				group = item.get_group();
			}
		}
	
		private void add_mute() {
			muted = new CheckButton.with_label("Muted");
			muted.toggled.connect(() => {
				try {
					devices.set_muted(default_device, muted.active);
					adjust_button_icon();
				}
				catch(PulseAudio.Error e) {
					stderr.printf("Error: %s\n", e.message);
				}
			});
			vbox.add(muted);
		}
	
		private void add_volume() {
			volume = new HScale.with_range(0, 100, 5);
			volume.draw_value = false;
			volume.change_value.connect((scroll, new_value) => {
				if(new_value >= 0 && new_value <= 100) {
					try {
						devices.set_volume(default_device, (int)new_value);
						adjust_button_icon();
					}
					catch(PulseAudio.Error e) {
						stderr.printf("Error: %s\n", e.message);
					}
					return false;
				}
				return true;
			});
			vbox.add(volume);
		}
		
		private void set_for_default() {
			volume.set_value(default_device.relative_volume);
			muted.active = default_device.is_muted;
			adjust_button_icon();
		}
		
		private void adjust_button_icon() {
			if(default_device.is_muted)
				button.set_image(images[Icons.MUTED]);
			else if(default_device.relative_volume <= 33)
				button.set_image(images[Icons.LOW]);
			else if(default_device.relative_volume <= 66)
				button.set_image(images[Icons.MEDIUM]);
			else
				button.set_image(images[Icons.HIGH]);
		}

		private Button button;	
		private Frame frm;
		private VBox vbox;
		private HScale volume;
		private CheckButton muted;
		private Device default_device;
		private DeviceContainer devices;
		private Image images[4];
	}
}

