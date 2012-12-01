using Xfce;
using Gee;
using Gtk;

namespace UI {
	public class PulseAudioPlugin : Xfce.PanelPlugin {
		public override void @construct() {
			button = new Button();
			button.clicked.connect(() => {
				try {
					if(menu.visible)
						menu.hide();
					else {
						menu.realize();
						menu.show_all();
						int x, y;
						position_func(menu, out x, out y);
						menu.move(x, y);
					}
				}
				catch(PulseAudio.Error e) {
					stderr.printf("Error: %s\n", e.message);
				}
			});
			add(button);
			button.show();
			add_action_widget(button);
			
			menu = new PopupMenu(button);
			
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

		private void position_func(Widget widget, out int x, out int y) {
			int height = button.allocation.height;
		
			Requisition req;
			widget.size_request(out req);
			button.get_window().get_origin(out x, out y);
			
		    // Show menu above
		    if(y + height + req.height > Gdk.Screen.height())
		        y -= req.height;
		    // Show menu below
		    else
		        y += height;

		    // Adjust horizontal position
		    if(x + req.width > Gdk.Screen.width())
		        x = Gdk.Screen.width() - req.width;
		}
		
		private PopupMenu? menu;
		private Button button;
	}
}

[ModuleInit]
public Type xfce_panel_module_init(TypeModule module) {
	return typeof(UI.PulseAudioPlugin);
}

