#include "include/flutter_desktop_lyrics/flutter_desktop_lyrics_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "flutter_desktop_lyrics_plugin_private.h"

#define FLUTTER_DESKTOP_LYRICS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_desktop_lyrics_plugin_get_type(), \
                              FlutterDesktopLyricsPlugin))

struct _FlutterDesktopLyricsPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  GtkCssProvider* css_provider;
};

G_DEFINE_TYPE(FlutterDesktopLyricsPlugin, flutter_desktop_lyrics_plugin, g_object_get_type())

static GtkWindow* get_window(FlutterDesktopLyricsPlugin* self) {
  if (self == nullptr || self->registrar == nullptr) {
    return nullptr;
  }
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (toplevel == nullptr || !GTK_IS_WINDOW(toplevel)) {
    return nullptr;
  }
  return GTK_WINDOW(toplevel);
}

static FlView* get_view(FlutterDesktopLyricsPlugin* self) {
  if (self == nullptr || self->registrar == nullptr) {
    return nullptr;
  }
  return fl_plugin_registrar_get_view(self->registrar);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void on_main_window_active_changed(GObject* object,
                                          GParamSpec* pspec,
                                          gpointer user_data) {
  GtkWindow* lyrics_win = GTK_WINDOW(user_data);
  if (lyrics_win != nullptr && gtk_widget_get_visible(GTK_WIDGET(lyrics_win))) {
    gtk_window_set_keep_above(lyrics_win, TRUE);
  }
}

static FlMethodResponse* initialize_lyrics_window(FlutterDesktopLyricsPlugin* self,
                                                  FlValue* args) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_WINDOW", "Native window handle not found", nullptr));
  }

  // 1. Remove window decoration & titlebar
  gtk_window_set_decorated(window, FALSE);
  GtkWidget* titlebar = gtk_window_get_titlebar(window);
  if (titlebar != nullptr) {
    gtk_widget_hide(titlebar);
  }

  // 2. Set window type hint to utility
  gtk_window_set_type_hint(window, GDK_WINDOW_TYPE_HINT_UTILITY);

  // 3. Keep above (Always on top)
  gtk_window_set_keep_above(window, TRUE);

  // 4. Skip taskbar & pager hints
  gtk_window_set_skip_taskbar_hint(window, TRUE);
  gtk_window_set_skip_pager_hint(window, TRUE);

  // 5. Do not accept / steal focus so clicking lyrics does not unfocus main window
  gtk_window_set_accept_focus(window, FALSE);
  gtk_window_set_focus_on_map(window, FALSE);

  // 6. Set transient for main window so Wayland / X11 always stacks lyrics ABOVE main window
  gtk_window_set_destroy_with_parent(window, FALSE);
  GtkApplication* app = GTK_APPLICATION(g_application_get_default());
  if (app != nullptr) {
    GList* windows = gtk_application_get_windows(app);
    for (GList* l = windows; l != nullptr; l = l->next) {
      GtkWindow* w = GTK_WINDOW(l->data);
      if (w != window) {
        gtk_window_set_transient_for(window, w);
        g_signal_connect_object(G_OBJECT(w), "notify::is-active",
                                G_CALLBACK(on_main_window_active_changed),
                                window, static_cast<GConnectFlags>(0));
        break;
      }
    }
  }

  // 4. App paintable & CSS transparent background
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);

  if (self->css_provider == nullptr) {
    self->css_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(
        self->css_provider,
        "window, decoration, .background {\n"
        "  background-color: transparent;\n"
        "  border-radius: 0;\n"
        "  box-shadow: none;\n"
        "  border: none;\n"
        "}\n",
        -1, nullptr);
    gtk_style_context_add_provider(
        gtk_widget_get_style_context(GTK_WIDGET(window)),
        GTK_STYLE_PROVIDER(self->css_provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER);
  }

  FlView* view = get_view(self);
  if (view != nullptr) {
    GdkRGBA bg_color = {0.0, 0.0, 0.0, 0.0};
    fl_view_set_background_color(view, &bg_color);
  }

  // 5. Parse dimensions and position
  int w = 920;
  int h = 150;
  int x = -1;
  int y = -1;

  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* w_val = fl_value_lookup_string(args, "width");
    if (w_val != nullptr) {
      if (fl_value_get_type(w_val) == FL_VALUE_TYPE_FLOAT) {
        w = static_cast<int>(fl_value_get_float(w_val));
      } else if (fl_value_get_type(w_val) == FL_VALUE_TYPE_INT) {
        w = static_cast<int>(fl_value_get_int(w_val));
      }
    }
    FlValue* h_val = fl_value_lookup_string(args, "height");
    if (h_val != nullptr) {
      if (fl_value_get_type(h_val) == FL_VALUE_TYPE_FLOAT) {
        h = static_cast<int>(fl_value_get_float(h_val));
      } else if (fl_value_get_type(h_val) == FL_VALUE_TYPE_INT) {
        h = static_cast<int>(fl_value_get_int(h_val));
      }
    }
    FlValue* x_val = fl_value_lookup_string(args, "x");
    if (x_val != nullptr) {
      if (fl_value_get_type(x_val) == FL_VALUE_TYPE_FLOAT) {
        x = static_cast<int>(fl_value_get_float(x_val));
      } else if (fl_value_get_type(x_val) == FL_VALUE_TYPE_INT) {
        x = static_cast<int>(fl_value_get_int(x_val));
      }
    }
    FlValue* y_val = fl_value_lookup_string(args, "y");
    if (y_val != nullptr) {
      if (fl_value_get_type(y_val) == FL_VALUE_TYPE_FLOAT) {
        y = static_cast<int>(fl_value_get_float(y_val));
      } else if (fl_value_get_type(y_val) == FL_VALUE_TYPE_INT) {
        y = static_cast<int>(fl_value_get_int(y_val));
      }
    }
  }

  if (x < 0 || y < 0) {
    GdkScreen* screen = gtk_window_get_screen(window);
    GdkDisplay* display = gdk_screen_get_display(screen);
    GdkMonitor* monitor = nullptr;
    GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_win != nullptr) {
      monitor = gdk_display_get_monitor_at_window(display, gdk_win);
    }
    if (monitor == nullptr) {
      monitor = gdk_display_get_primary_monitor(display);
    }
    if (monitor == nullptr && gdk_display_get_n_monitors(display) > 0) {
      monitor = gdk_display_get_monitor(display, 0);
    }

    if (monitor != nullptr) {
      GdkRectangle workarea;
      gdk_monitor_get_workarea(monitor, &workarea);
      if (x < 0) x = workarea.x + (workarea.width - w) / 2;
      if (y < 0) y = workarea.y + workarea.height - h - 60;
    } else {
      if (x < 0) x = (1920 - w) / 2;
      if (y < 0) y = 1080 - h - 60;
    }
  }

  gtk_window_resize(window, w, h);
  gtk_window_move(window, x, y);
  gtk_widget_show_all(GTK_WIDGET(window));

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_click_through(FlutterDesktopLyricsPlugin* self,
                                          FlValue* args) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_WINDOW", "Native window handle not found", nullptr));
  }

  bool enabled = false;
  if (args != nullptr) {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_BOOL) {
      enabled = fl_value_get_bool(args);
    } else if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* val = fl_value_lookup_string(args, "enabled");
      if (val != nullptr && fl_value_get_type(val) == FL_VALUE_TYPE_BOOL) {
        enabled = fl_value_get_bool(val);
      }
    }
  }

  if (enabled) {
    cairo_region_t* region = cairo_region_create();
    gtk_widget_input_shape_combine_region(GTK_WIDGET(window), region);
    cairo_region_destroy(region);
  } else {
    gtk_widget_input_shape_combine_region(GTK_WIDGET(window), nullptr);
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_always_on_top(FlutterDesktopLyricsPlugin* self,
                                          FlValue* args) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_WINDOW", "Native window handle not found", nullptr));
  }

  bool is_always_on_top = true;
  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL) {
    is_always_on_top = fl_value_get_bool(args);
  }

  gtk_window_set_keep_above(window, is_always_on_top ? TRUE : FALSE);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* start_dragging(FlutterDesktopLyricsPlugin* self) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_WINDOW", "Native window handle not found", nullptr));
  }

  GdkScreen* screen = gtk_window_get_screen(window);
  GdkDisplay* display = gdk_screen_get_display(screen);
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* device = (seat != nullptr) ? gdk_seat_get_pointer(seat) : nullptr;

  gint root_x = 0;
  gint root_y = 0;
  if (device != nullptr) {
    gdk_device_get_position(device, nullptr, &root_x, &root_y);
  }
  guint32 timestamp = static_cast<guint32>(g_get_monotonic_time());

  gtk_window_begin_move_drag(window, 1, root_x, root_y, timestamp);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_window_bounds(FlutterDesktopLyricsPlugin* self,
                                          FlValue* args) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_WINDOW", "Native window handle not found", nullptr));
  }

  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* w_val = fl_value_lookup_string(args, "width");
    FlValue* h_val = fl_value_lookup_string(args, "height");
    FlValue* x_val = fl_value_lookup_string(args, "x");
    FlValue* y_val = fl_value_lookup_string(args, "y");

    if (w_val != nullptr && h_val != nullptr) {
      int w = (fl_value_get_type(w_val) == FL_VALUE_TYPE_FLOAT)
                  ? static_cast<int>(fl_value_get_float(w_val))
                  : static_cast<int>(fl_value_get_int(w_val));
      int h = (fl_value_get_type(h_val) == FL_VALUE_TYPE_FLOAT)
                  ? static_cast<int>(fl_value_get_float(h_val))
                  : static_cast<int>(fl_value_get_int(h_val));
      gtk_window_resize(window, w, h);
    }

    if (x_val != nullptr && y_val != nullptr) {
      int x = (fl_value_get_type(x_val) == FL_VALUE_TYPE_FLOAT)
                  ? static_cast<int>(fl_value_get_float(x_val))
                  : static_cast<int>(fl_value_get_int(x_val));
      int y = (fl_value_get_type(y_val) == FL_VALUE_TYPE_FLOAT)
                  ? static_cast<int>(fl_value_get_float(y_val))
                  : static_cast<int>(fl_value_get_int(y_val));
      gtk_window_move(window, x, y);
    }

    g_autoptr(FlValue) result = fl_value_new_bool(true);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENTS", "Expected map for setWindowBounds", nullptr));
}

static FlMethodResponse* get_window_bounds(FlutterDesktopLyricsPlugin* self) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_WINDOW", "Native window handle not found", nullptr));
  }

  gint x = 0;
  gint y = 0;
  gint w = 0;
  gint h = 0;
  gtk_window_get_position(window, &x, &y);
  gtk_window_get_size(window, &w, &h);

  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "x", fl_value_new_float(static_cast<double>(x)));
  fl_value_set_string_take(map, "y", fl_value_new_float(static_cast<double>(y)));
  fl_value_set_string_take(map, "width", fl_value_new_float(static_cast<double>(w)));
  fl_value_set_string_take(map, "height", fl_value_new_float(static_cast<double>(h)));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static FlMethodResponse* show_window(FlutterDesktopLyricsPlugin* self) {
  GtkWindow* window = get_window(self);
  if (window != nullptr) {
    gtk_widget_show(GTK_WIDGET(window));
    gtk_window_set_keep_above(window, TRUE);
  }
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* hide_window(FlutterDesktopLyricsPlugin* self) {
  GtkWindow* window = get_window(self);
  if (window != nullptr) {
    gtk_widget_hide(GTK_WIDGET(window));
  }
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Called when a method call is received from Flutter.
static void flutter_desktop_lyrics_plugin_handle_method_call(
    FlutterDesktopLyricsPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "initializeLyricsWindow") == 0) {
    response = initialize_lyrics_window(self, fl_method_call_get_args(method_call));
  } else if (strcmp(method, "setClickThrough") == 0) {
    response = set_click_through(self, fl_method_call_get_args(method_call));
  } else if (strcmp(method, "setAlwaysOnTop") == 0) {
    response = set_always_on_top(self, fl_method_call_get_args(method_call));
  } else if (strcmp(method, "startDragging") == 0) {
    response = start_dragging(self);
  } else if (strcmp(method, "setWindowBounds") == 0) {
    response = set_window_bounds(self, fl_method_call_get_args(method_call));
  } else if (strcmp(method, "getWindowBounds") == 0) {
    response = get_window_bounds(self);
  } else if (strcmp(method, "showWindow") == 0) {
    response = show_window(self);
  } else if (strcmp(method, "hideWindow") == 0) {
    response = hide_window(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void flutter_desktop_lyrics_plugin_dispose(GObject* object) {
  FlutterDesktopLyricsPlugin* self = FLUTTER_DESKTOP_LYRICS_PLUGIN(object);
  if (self->css_provider != nullptr) {
    g_clear_object(&self->css_provider);
  }
  if (self->registrar != nullptr) {
    g_clear_object(&self->registrar);
  }
  G_OBJECT_CLASS(flutter_desktop_lyrics_plugin_parent_class)->dispose(object);
}

static void flutter_desktop_lyrics_plugin_class_init(FlutterDesktopLyricsPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_desktop_lyrics_plugin_dispose;
}

static void flutter_desktop_lyrics_plugin_init(FlutterDesktopLyricsPlugin* self) {
  self->registrar = nullptr;
  self->css_provider = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterDesktopLyricsPlugin* plugin = FLUTTER_DESKTOP_LYRICS_PLUGIN(user_data);
  flutter_desktop_lyrics_plugin_handle_method_call(plugin, method_call);
}

void flutter_desktop_lyrics_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterDesktopLyricsPlugin* plugin = FLUTTER_DESKTOP_LYRICS_PLUGIN(
      g_object_new(flutter_desktop_lyrics_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "flutter_desktop_lyrics",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
