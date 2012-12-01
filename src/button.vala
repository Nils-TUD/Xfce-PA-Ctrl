using Xfce;
using Gee;

public class ButtonPlugin : Xfce.PanelPlugin {
	private Gtk.Button button;

	private void my_position_func(Gtk.Menu menu, out int x, out int y, out bool push_in) {
		int height = button.allocation.height;
		
		Gtk.Requisition requisition;
		menu.size_request(out requisition);
		button.get_window().get_origin(out x, out y);
		
        // Show menu above
        if(y + height + requisition.height > Gdk.Screen.height())
            y -= requisition.height;
        // Show menu below
        else
            y += height;

        // Adjust horizontal position
        if(x + requisition.width > Gdk.Screen.width())
            x = Gdk.Screen.width() - requisition.width;
        push_in = false;
	}
	
	private void parse_pulseaudio_dump() {
		try {
			var pa = new PulseAudio.DeviceContainer();
			foreach(PulseAudio.Device dev in pa) {
				stdout.printf("id=%d, name=%s volume=%d def=%d muted=%d\n", dev.index, dev.name, dev.volume, (int)dev.is_default, (int)dev.is_muted);
			}
		}
		catch(PulseAudio.DumpError e) {
			stderr.printf("Error: %s\n", e.message);
		}
	}

	public override void @construct() {
		button = new Gtk.Button();
		button.set_image(new Gtk.Image.from_file("/home/hrniels/xfce-pa-ctrl/build/debug/bin/icon.png"));
		button.clicked.connect(() => {
			Gtk.Menu menu = new Gtk.Menu();
			try {
				var pa = new PulseAudio.DeviceContainer();
				foreach(PulseAudio.Device dev in pa) {
					Gtk.MenuItem item = new Gtk.MenuItem.with_label(dev.name);
					menu.add(item);
					//stdout.printf("id=%d, name=%s volume=%d def=%d muted=%d\n", dev.index, dev.name, dev.volume, (int)dev.is_default, (int)dev.is_muted);
				}
				menu.show_all();
				menu.popup(null, null, this.my_position_func, 0, 0);
			}
			catch(PulseAudio.DumpError e) {
				stderr.printf("Error: %s\n", e.message);
			}
		});
		add(button);
		button.show();
		add_action_widget(button);
		
		parse_pulseaudio_dump();

		save.connect (() => { message ("save yourself"); });
		free_data.connect (() => { message ("free yourself"); });
		size_changed.connect (() => { message ("panel size changed"); return false; });

		menu_show_about ();
		about.connect (() => {
				Gtk.show_about_dialog (null,
					"program-name", "Button",
					"comments", "Test plugin for the Xfce 4.7 Panel",
					null);
			});

		destroy.connect (() => { Gtk.main_quit (); });
	}
}

[ModuleInit]
public Type xfce_panel_module_init (TypeModule module) {
	return typeof (ButtonPlugin);
}
