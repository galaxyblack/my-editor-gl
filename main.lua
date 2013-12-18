local STP = require 'StackTracePlus'
debug.traceback = STP.stacktrace

require 'Strict'
decl = Strict.declareGlobal
Strict.strong = true
decl('_')

local lgi = require 'lgi'
decl('Gtk')
Gtk = lgi.require('Gtk', '3.0')
decl('GtkSource')
GtkSource = lgi.require('GtkSource', '3.0')
decl('GLib')
GLib = lgi.require('GLib', '2.0')
decl('Gdk')
Gdk = lgi.Gdk
decl('Pango')
Pango = lgi.Pango
decl('GObject')
GObject = lgi.GObject

require 'object'
require 'utils'

require 'editor'

decl('MainWindow')
MainWindow = class{function(self)
  self.widget = Gtk.Window{type = Gtk.WindowType.TOPLEVEL}
  self.widget.on_destroy:connect(function()
    Gtk.main_quit()
  end)
  self.widget:set_title('my editor')

  -- css
  local css_provider = Gtk.CssProvider()
  css_provider:load_from_data(io.open('style.css', 'r'):read('*a'))
  Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(),
    css_provider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

  -- top container
  self.root_container = Gtk.Overlay()
  self.widget:add(self.root_container)

  -- editor
  self.editor = Editor()
  self.root_container:add(self.editor.widget)

end}
MainWindow.embed('widget')

local win = MainWindow()

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, function()
  check_jobs()
  return true
end)

win.widget:show_all()
Gtk.main()
