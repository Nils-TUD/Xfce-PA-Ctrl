using Xfce;
using Gee;
using Gtk;

namespace UI {
	public class PulseAudioPlugin : Xfce.PanelPlugin {
		public override void @construct() {
			button = new Button();
			button.set_image(new Image.from_icon_name("audio-volume-high", IconSize.BUTTON));
			button.clicked.connect(() => {
				try {
					PopupMenu menu = new PopupMenu();
					menu.show_all();
					menu.popup(null, null, this.popup_position_func, 0, 0);
				}
				catch(PulseAudio.Error e) {
					stderr.printf("Error: %s\n", e.message);
				}
			});
			add(button);
			button.show();
			add_action_widget(button);
		
			menu_show_about();
			about.connect(() => {
				show_about_dialog(null,
					"program-name", "Pulse Audio Control",
					"comments", "Let's you choose the device, control the volume and mute/unmute devices",
					null);
			});

			destroy.connect(() => {
				main_quit();
			});
		}

		private void popup_position_func(Gtk.Menu menu, out int x, out int y, out bool push_in) {
			int height = button.allocation.height;
		
			Requisition requisition;
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
		
		private Button button;
	}
}

[ModuleInit]
public Type xfce_panel_module_init(TypeModule module) {
	return typeof(UI.PulseAudioPlugin);
}

