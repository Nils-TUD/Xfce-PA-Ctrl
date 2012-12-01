using PulseAudio;
using Gtk;

namespace UI {
	public class PopupMenu : Gtk.Menu {
		public PopupMenu() throws PulseAudio.Error {
			devices = new DeviceContainer();
			default_device = devices.default_device();
		
			add_devices();
			add(new SeparatorMenuItem());
			add_mute();
			add_volume();
		}
	
		private void add_devices() {
			unowned SList<RadioMenuItem> group = null;
			foreach(Device dev in devices) {
				RadioMenuItem item = new RadioMenuItem.with_label(group, dev.nice_name);
				item.set_active(dev.is_default);
				item.toggled.connect(() => {
					try {
						if(item.active)
							devices.set_default(dev);
					}
					catch(PulseAudio.Error e) {
						stderr.printf("Error: %s\n", e.message);
					}
				});
				add(item);
				group = item.get_group();
			}
		}
	
		private void add_mute() {
			var item = new CheckMenuItem.with_label("Muted");
			item.active = default_device.is_muted;
			item.toggled.connect(() => {
				try {
					devices.toggle_muted();
				}
				catch(PulseAudio.Error e) {
					stderr.printf("Error: %s\n", e.message);
				}
			});
			add(item);
		}
	
		private void add_volume() {
			var item = new Gtk.MenuItem();
			var hscale = new HScale.with_range(0, 100, 5);
			hscale.draw_value = false;
			hscale.set_value(default_device.relative_volume);
			var eventbox = new EventBox();
			eventbox.add(hscale);
			item.add(eventbox);
			add(item);
		}
	
		private Device default_device;
		private DeviceContainer devices;
	}
}

