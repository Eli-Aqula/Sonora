#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <dwmapi.h>

#include "flutter_window.h"
#include "utils.h"

// DWM-атрибуты для кастомного цвета заголовка окна (Windows 11 22H2+).
// В публичных заголовках их пока нет, поэтому объявляем вручную.
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1366, 800);
  if (!window.Create(L"Sonora", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Красим системный заголовок окна в чёрный, текст — в белый.
  // Работает на Windows 11 22H2+; на более старых версиях атрибут
  // просто игнорируется.
  HWND hwnd = window.GetHandle();
  if (hwnd != nullptr) {
    const COLORREF kBlack = RGB(0, 0, 0);
    const COLORREF kWhite = RGB(255, 255, 255);
    ::DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &kBlack,
                            sizeof(kBlack));
    ::DwmSetWindowAttribute(hwnd, DWMWA_TEXT_COLOR, &kWhite,
                            sizeof(kWhite));
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
