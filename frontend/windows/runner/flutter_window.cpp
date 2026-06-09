#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  hwnd_ = GetHandle();

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  ime_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.xjtu.genius/ime",
          &flutter::StandardMethodCodec::GetInstance());

  ime_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "saveCurrentIme") {
          saved_layout_ = GetKeyboardLayout(0);
          result->Success();
        } else if (call.method_name() == "switchToEnglish") {
          if (english_layout_ == 0) {
            english_layout_ = LoadKeyboardLayoutW(L"00000409", KLF_ACTIVATE);
          }
          if (english_layout_ != nullptr) {
            ActivateKeyboardLayout(english_layout_, KLF_ACTIVATE);
            result->Success(flutter::EncodableValue(true));
          } else {
            result->Error("FAILED", "LoadKeyboardLayout failed");
          }
        } else if (call.method_name() == "restoreIme") {
          if (saved_layout_ != 0) {
            ActivateKeyboardLayout(saved_layout_, KLF_ACTIVATE);
            saved_layout_ = 0;
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (hwnd_ == nullptr) {
    hwnd_ = hwnd;
  }

  if (message == WM_ACTIVATEAPP) {
    if (wparam == FALSE && saved_layout_ != 0) {
      ActivateKeyboardLayout(saved_layout_, KLF_ACTIVATE);
      PostMessage(HWND_BROADCAST, WM_INPUTLANGCHANGEREQUEST,
                  0, reinterpret_cast<LPARAM>(saved_layout_));
      sw_app_deactivate = true;
    } else if (wparam == TRUE && sw_app_deactivate) {
      sw_app_deactivate = false;
      if (english_layout_ != 0) {
        ActivateKeyboardLayout(english_layout_, KLF_ACTIVATE);
      }
    }
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
