#include "flutter_desktop_lyrics_plugin.h"

#include <windows.h>
#include <dwmapi.h>
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_desktop_lyrics {

// static
void FlutterDesktopLyricsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_desktop_lyrics",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterDesktopLyricsPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterDesktopLyricsPlugin::FlutterDesktopLyricsPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {}

FlutterDesktopLyricsPlugin::~FlutterDesktopLyricsPlugin() {}

HWND FlutterDesktopLyricsPlugin::GetWindowHandle() const {
  if (!registrar_ || !registrar_->GetView()) {
    return nullptr;
  }
  return ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
}

void FlutterDesktopLyricsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND hwnd = GetWindowHandle();
  if (!hwnd) {
    result->Error("NO_WINDOW", "Could not obtain native window handle");
    return;
  }

  const auto &method = method_call.method_name();

  if (method == "initializeLyricsWindow") {
    // Remove titlebar and borders, set POPUP style
    LONG_PTR style = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    style |= WS_POPUP;
    ::SetWindowLongPtr(hwnd, GWL_STYLE, style);

    // Extended styles: layered, topmost, tool window (hide from taskbar)
    LONG_PTR ex_style = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    ex_style |= (WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW);
    ex_style &= ~WS_EX_APPWINDOW;
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex_style);

    // DWM extend client area for transparent background
    MARGINS margins = {-1, -1, -1, -1};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);

    // Parse dimensions and initial position
    int w = 920;
    int h = 150;
    int x = -1;
    int y = -1;

    if (method_call.arguments()) {
      if (const auto *map = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
        auto w_it = map->find(flutter::EncodableValue("width"));
        if (w_it != map->end()) {
          if (const auto *val = std::get_if<double>(&w_it->second)) w = static_cast<int>(*val);
          else if (const auto *val_i = std::get_if<int>(&w_it->second)) w = *val_i;
        }
        auto h_it = map->find(flutter::EncodableValue("height"));
        if (h_it != map->end()) {
          if (const auto *val = std::get_if<double>(&h_it->second)) h = static_cast<int>(*val);
          else if (const auto *val_i = std::get_if<int>(&h_it->second)) h = *val_i;
        }
        auto x_it = map->find(flutter::EncodableValue("x"));
        if (x_it != map->end()) {
          if (const auto *val = std::get_if<double>(&x_it->second)) x = static_cast<int>(*val);
          else if (const auto *val_i = std::get_if<int>(&x_it->second)) x = *val_i;
        }
        auto y_it = map->find(flutter::EncodableValue("y"));
        if (y_it != map->end()) {
          if (const auto *val = std::get_if<double>(&y_it->second)) y = static_cast<int>(*val);
          else if (const auto *val_i = std::get_if<int>(&y_it->second)) y = *val_i;
        }
      }
    }

    if (x < 0 || y < 0) {
      RECT workArea;
      SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0);
      int screenW = workArea.right - workArea.left;
      int screenH = workArea.bottom - workArea.top;
      x = workArea.left + (screenW - w) / 2;
      y = workArea.top + screenH - h - 60; // Default bottom-aligned floating
    }

    ::SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW);

    result->Success(flutter::EncodableValue(true));
  } else if (method == "setClickThrough") {
    bool enabled = false;
    if (const auto *val = std::get_if<bool>(method_call.arguments())) {
      enabled = *val;
    } else if (const auto *map = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      auto it = map->find(flutter::EncodableValue("enabled"));
      if (it != map->end() && std::holds_alternative<bool>(it->second)) {
        enabled = std::get<bool>(it->second);
      }
    }

    LONG_PTR ex_style = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    if (enabled) {
      ex_style |= WS_EX_TRANSPARENT;
    } else {
      ex_style &= ~WS_EX_TRANSPARENT;
    }
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex_style);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setAlwaysOnTop") {
    bool isAlwaysOnTop = true;
    if (const auto *val = std::get_if<bool>(method_call.arguments())) {
      isAlwaysOnTop = *val;
    }
    ::SetWindowPos(hwnd, isAlwaysOnTop ? HWND_TOPMOST : HWND_NOTOPMOST,
                   0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "startDragging") {
    ::ReleaseCapture();
    ::SendMessage(hwnd, WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setWindowBounds") {
    if (const auto *map = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      int x = 0, y = 0, w = 920, h = 150;
      auto x_it = map->find(flutter::EncodableValue("x"));
      if (x_it != map->end()) {
        if (const auto *val = std::get_if<double>(&x_it->second)) x = static_cast<int>(*val);
        else if (const auto *val_i = std::get_if<int>(&x_it->second)) x = *val_i;
      }
      auto y_it = map->find(flutter::EncodableValue("y"));
      if (y_it != map->end()) {
        if (const auto *val = std::get_if<double>(&y_it->second)) y = static_cast<int>(*val);
        else if (const auto *val_i = std::get_if<int>(&y_it->second)) y = *val_i;
      }
      auto w_it = map->find(flutter::EncodableValue("width"));
      if (w_it != map->end()) {
        if (const auto *val = std::get_if<double>(&w_it->second)) w = static_cast<int>(*val);
        else if (const auto *val_i = std::get_if<int>(&w_it->second)) w = *val_i;
      }
      auto h_it = map->find(flutter::EncodableValue("height"));
      if (h_it != map->end()) {
        if (const auto *val = std::get_if<double>(&h_it->second)) h = static_cast<int>(*val);
        else if (const auto *val_i = std::get_if<int>(&h_it->second)) h = *val_i;
      }
      ::SetWindowPos(hwnd, nullptr, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE);
      result->Success(flutter::EncodableValue(true));
      return;
    }
    result->Error("INVALID_ARGUMENTS", "Expected map for setWindowBounds");
  } else if (method == "getWindowBounds") {
    RECT rect;
    if (::GetWindowRect(hwnd, &rect)) {
      flutter::EncodableMap bounds;
      bounds[flutter::EncodableValue("x")] = flutter::EncodableValue(static_cast<double>(rect.left));
      bounds[flutter::EncodableValue("y")] = flutter::EncodableValue(static_cast<double>(rect.top));
      bounds[flutter::EncodableValue("width")] = flutter::EncodableValue(static_cast<double>(rect.right - rect.left));
      bounds[flutter::EncodableValue("height")] = flutter::EncodableValue(static_cast<double>(rect.bottom - rect.top));
      result->Success(flutter::EncodableValue(bounds));
      return;
    }
    result->Error("GET_RECT_FAILED", "Failed to get window rect");
  } else if (method == "showWindow") {
    ::ShowWindow(hwnd, SW_SHOWNA);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "hideWindow") {
    ::ShowWindow(hwnd, SW_HIDE);
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_desktop_lyrics

