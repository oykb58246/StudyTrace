#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

bool ParseWindowSize(const std::string& value, unsigned int* width,
                     unsigned int* height) {
  const auto separator = value.find_first_of("xX");
  if (separator == std::string::npos) {
    return false;
  }
  try {
    const auto parsed_width = std::stoul(value.substr(0, separator));
    const auto parsed_height = std::stoul(value.substr(separator + 1));
    if (parsed_width < 320 || parsed_height < 480) {
      return false;
    }
    *width = static_cast<unsigned int>(parsed_width);
    *height = static_cast<unsigned int>(parsed_height);
    return true;
  } catch (...) {
    return false;
  }
}

Win32Window::Size ResolveInitialWindowSize(
    const std::vector<std::string>& arguments) {
  unsigned int width = 430;
  unsigned int height = 900;
  for (const auto& argument : arguments) {
    constexpr char prefix[] = "--studytrace-window-size=";
    if (argument.rfind(prefix, 0) == 0 &&
        ParseWindowSize(argument.substr(sizeof(prefix) - 1), &width, &height)) {
      return Win32Window::Size(width, height);
    }
    if (argument == "--studytrace-ui-review-window") {
      return Win32Window::Size(430, 900);
    }
  }

  char environment_value[32];
  const auto length = GetEnvironmentVariableA(
      "STUDYTRACE_WINDOW_SIZE", environment_value, sizeof(environment_value));
  if (length > 0 && length < sizeof(environment_value) &&
      ParseWindowSize(environment_value, &width, &height)) {
    return Win32Window::Size(width, height);
  }

  return Win32Window::Size(width, height);
}

}  // namespace

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
  Win32Window::Size size = ResolveInitialWindowSize(command_line_arguments);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  if (!window.Create(L"StudyTrace", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
