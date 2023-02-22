namespace Vlauncher {

class StringMatcher {
public static int get_score(string? sample, string? pattern) {
	if (sample == null || pattern == null || sample.length == 0 || pattern.length == 0) {return 0;}

	var s = sample.down();
	var p = pattern.down();

	for (var length = p.length; length > int.min(p.length-1, 5); length -= 1) {
		for (var start = 0; start <= p.length - length; start += 1) {
			var idx = s.index_of(p.substring(start, length));
			if (idx != -1) {
				var rate = 100 * length * length / p.length / p.length;

				if (idx == 0 || idx == s.length - length) {
					rate += 10;
				}

				return int.min(rate, 100);
			}
		}
	}
	return 0;
}
}

public class Entry : Gtk.Entry {
construct {
	get_style_context().add_class("input");
	width_request = 410;
}
}
public class Item : Gtk.Box {
public AppInfo info;
string last_pattern;
int last_rate;

public int rate(string pattern) {
	if (pattern != last_pattern) {
		last_pattern = pattern;
		var name = StringMatcher.get_score(info.get_name(), pattern);
		var exe = StringMatcher.get_score(info.get_executable(), pattern);
		var desc = StringMatcher.get_score(info.get_description(), pattern);
		last_rate = (int.max(int.max(4 * name, 3 * exe), 2 * desc)) / 4;
	}
	return last_rate;
}


public Item(AppInfo _info) {
	Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 10);
	info = _info;

	var l = new Gtk.Label(info.get_display_name());
	l.get_style_context().add_class("name");
	l.xalign = 0;

	var d = new Gtk.Label(info.get_description());
	d.get_style_context().add_class("description");
	d.ellipsize = Pango.EllipsizeMode.END;
	d.xalign = 0;

	var f = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
	f.append(l);
	f.append(d);

	append(new Gtk.Image.from_gicon(info.get_icon()));
	append(f);

	get_style_context().add_class("item");
}

public void launch() {
	try {
		Process.spawn_async(null, {"gtk-launch", info.get_id()}, null, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, null);
	} catch (GLib.SpawnError e) {
		print("Launch failed: " + e.message);
	}
}
}

public class Window : Adw.ApplicationWindow {
const string style = ".input { font-size: 200%; font-weight: 200; padding: 10px 10px;} .item { padding: 10px 5px; } .name { font-size: 120%; } .desc { font-size: 80%; }";

Gtk.ListBox results;
Gtk.ScrolledWindow scroll;
Entry entry;

construct {
	try {
		var display = get_display ();
		var css_provider = new Gtk.CssProvider();
		css_provider.load_from_data(style.data);
		Gtk.StyleContext.add_provider_for_display(display, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
	} catch (Error e) {
		error ("Cannot load CSS stylesheet: %s", e.message);
	}

	entry = new Entry();
	entry.changed.connect((_) => on_query_update(entry.buffer.text));

	results = new Gtk.ListBox();
	results.set_sort_func((r1, r2) => sort_function(r1, r2));
	results.row_activated.connect((row) => launch(row));
	initialize_results();

	scroll = new Gtk.ScrolledWindow();
	scroll.max_content_height = 500;
	scroll.propagate_natural_height = true;
	scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
	scroll.child = results;
	scroll.set_visible(false);

	var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
	box.append(entry);
	box.append(scroll);

	content = box;
	title = "Vlauncher - Application Launcher";
	resizable = false;
	deletable = false;

	var c = new Gtk.EventControllerKey ();
	c.propagation_phase = Gtk.PropagationPhase.CAPTURE;
	c.key_pressed.connect ((keyval, keycode, modifier) => key_handler(keyval, keycode, modifier));
	(this as Gtk.Widget)?.add_controller(c);
}

void initialize_results() {
	var i = 0;
	foreach (AppInfo app_info in AppInfo.get_all()) {
		if (app_info.should_show()) {
			var item = new Item(app_info);
			results.append(item);
			results.get_row_at_index(i).set_visible(false);
			i += 1;
		}
	}
}

void launch(Gtk.ListBoxRow row) {
	(row.child as Item)?.launch();
	application.quit();
}

void on_query_update(string query) {
	var threshold = 40;
	results.invalidate_sort();

	var i = 0;
	var visible = 0;
	while (true) {
		var row = results.get_row_at_index(i);
		if (row == null) {break;}
		var item = (Item)row.child;
		var rate = item.rate(query);
		row.set_visible(rate > threshold);
		visible += (rate > threshold) ? 1 : 0;
		i += 1;
	}

	if (visible > 0) {
		var row = results.get_row_at_index(0);
		results.select_row(row);
		row.grab_focus();
		entry.grab_focus_without_selecting();
	}

	scroll.set_visible(visible > 0);
}

int sort_function(Gtk.ListBoxRow r1, Gtk.ListBoxRow r2){
	var query = entry.buffer.text;
	var i1 = (Item) r1.child;
	var i2 = (Item) r2.child;
	return i2.rate(query) - i1.rate(query);
}

bool key_handler(uint keyval, uint keycode, Gdk.ModifierType modifier) {
	if (keyval == Gdk.Key.Escape) {
		application.quit();
	}
	else if ((keyval == Gdk.Key.Up) || (keyval == Gdk.Key.Down)) {
		var row = results.get_selected_row();
		var index = (row == null) ? -1 : row.get_index();
		var step = (keyval == Gdk.Key.Down) ? 1 : -1;
		index = index + step;
		row = results.get_row_at_index(index);
		if (row == null || !row.visible) {return true;}
		results.select_row(row);
		row.grab_focus();
		entry.grab_focus_without_selecting();
	} else if (keyval == Gdk.Key.Return) {
		results.get_selected_row().activate();
	} else {return false;}
	return true;
}

public Window (Gtk.Application app) {
	Object(application: app);
}
}

public class Application : Adw.Application {
public Application() {
	Object (
		application_id: "com.github.vlabdrake.vlauncher",
		flags: ApplicationFlags.FLAGS_NONE
		);
}
public override void activate () {
	new Window (this).show ();
}
}
}

int main (string[] args) {
	return new Vlauncher.Application().run(args);
}
