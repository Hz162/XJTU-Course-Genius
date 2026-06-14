#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* ime_channel;
};

// Saved keyboard layout for IME restore
static char* saved_layout = NULL;
static guint focus_out_timer = 0;

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void ime_switch_to_english() {
  system("setxkbmap us 2>/dev/null");
}

static gboolean delayed_ime_restore(gpointer user_data) {
  if (saved_layout && saved_layout[0] != '\0') {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "setxkbmap %s 2>/dev/null", saved_layout);
    system(cmd);
  }
  focus_out_timer = 0;
  return G_SOURCE_REMOVE;
}

static gboolean on_window_focus_out(GtkWidget* widget, GdkEventFocus* event,
                                     gpointer user_data) {
  // Cancel any pending restore for field-to-field transitions
  if (focus_out_timer) g_source_remove(focus_out_timer);
  // App losing focus: restore original IME for other apps, keep saved_layout
  if (saved_layout && saved_layout[0] != '\0') {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "setxkbmap %s 2>/dev/null", saved_layout);
    system(cmd);
  }
  focus_out_timer = 0;
  return FALSE;
}

static gboolean on_window_focus_in(GtkWidget* widget, GdkEventFocus* event,
                                    gpointer user_data) {
  // Cancel any pending delayed restore
  if (focus_out_timer) {
    g_source_remove(focus_out_timer);
    focus_out_timer = 0;
  }
  // App regaining focus: switch back to English if IME was saved
  if (saved_layout && saved_layout[0] != '\0') {
    ime_switch_to_english();
  }
  return FALSE;
}

static void ime_method_call_handler(FlMethodChannel* channel,
                                     FlMethodCall* method_call,
                                     gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(GError) error = NULL;

  if (g_strcmp0(method, "saveCurrentIme") == 0) {
    g_free(saved_layout);
    saved_layout = NULL;
    FILE* fp = popen(
        "setxkbmap -query 2>/dev/null | grep layout | awk '{print $2}'", "r");
    if (fp) {
      char buf[64] = {0};
      if (fgets(buf, sizeof(buf), fp)) {
        size_t len = strlen(buf);
        if (len > 0 && buf[len - 1] == '\n') buf[len - 1] = '\0';
        saved_layout = g_strdup(buf);
      }
      pclose(fp);
    }
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(channel, method_call, result, &error);
  } else if (g_strcmp0(method, "switchToEnglish") == 0) {
    ime_switch_to_english();
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(channel, method_call, result, &error);
  } else if (g_strcmp0(method, "restoreIme") == 0) {
    if (saved_layout && saved_layout[0] != '\0') {
      char cmd[256];
      snprintf(cmd, sizeof(cmd), "setxkbmap %s 2>/dev/null", saved_layout);
      system(cmd);
    }
    g_free(saved_layout);
    saved_layout = NULL;
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(channel, method_call, result, &error);
  } else {
    fl_method_call_respond_not_implemented(channel, method_call, &error);
  }
  if (error != NULL) {
    g_warning("IME method channel response error: %s", error->message);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "");
  }

  gtk_window_set_default_size(window, 1280, 720);
  g_signal_connect(window, "focus-out-event", G_CALLBACK(on_window_focus_out), NULL);
  g_signal_connect(window, "focus-in-event", G_CALLBACK(on_window_focus_in), NULL);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Set up IME method channel: switch keyboard to English on Linux
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->ime_channel = fl_method_channel_new(
      messenger, "com.xjtu.genius/ime", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->ime_channel, ime_method_call_handler, NULL, NULL);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->ime_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
