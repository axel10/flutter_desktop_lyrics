#include "include/flutter_desktop_lyrics/flutter_desktop_lyrics_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_desktop_lyrics_plugin.h"

void FlutterDesktopLyricsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_desktop_lyrics::FlutterDesktopLyricsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
