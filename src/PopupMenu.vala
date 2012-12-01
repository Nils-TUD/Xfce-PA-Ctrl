using PulseAudio;
using Gtk;

namespace UI {
	public class PopupMenu : Gtk.Window {
		public PopupMenu(Button btn) throws PulseAudio.Error {
			// images for the panel-button
			images[0] = new Image.from_icon_name("audio-volume-muted", IconSize.BUTTON);
			images[1] = new Image.from_icon_name("audio-volume-low", IconSize.BUTTON);
			images[2] = new Image.from_icon_name("audio-volume-medium", IconSize.BUTTON);
			images[3] = new Image.from_icon_name("audio-volume-high", IconSize.BUTTON);
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
			adjust_button_icon();
		
			// add widgets
			add_devices();
			vbox.add(new HSeparator());
			add_mute();
			add_volume();
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
			var item = new CheckButton.with_label("Muted");
			item.active = default_device.is_muted;
			item.toggled.connect(() => {
				try {
					devices.toggle_muted();
					adjust_button_icon();
				}
				catch(PulseAudio.Error e) {
					stderr.printf("Error: %s\n", e.message);
				}
			});
			vbox.add(item);
		}
	
		private void add_volume() {
			volume = new HScale.with_range(0, 100, 5);
			volume.draw_value = false;
			volume.set_value(default_device.relative_volume);
			volume.change_value.connect((scroll, new_value) => {
				if(new_value >= 0 && new_value <= 100) {
					try {
						devices.set_volume((int)new_value);
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
		
		private void adjust_button_icon() {
			if(default_device.is_muted)
				button.set_image(images[0]);
			else if(default_device.relative_volume <= 33)
				button.set_image(images[1]);
			else if(default_device.relative_volume <= 66)
				button.set_image(images[2]);
			else
				button.set_image(images[3]);
		}

		private Button button;	
		private Frame frm;
		private VBox vbox;
		private HScale volume;
		private Device default_device;
		private DeviceContainer devices;
		private Image images[4];
	}
}

