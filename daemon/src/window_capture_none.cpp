// open_window_capture on platforms without ScreenCaptureKit (window_capture.h).

#include "backend.h"
#include "window_capture.h"

namespace gamepilot {

std::unique_ptr<FrameSource> open_window_capture(const WindowCaptureConfig&) {
  throw BackendError("window capture needs macOS (ScreenCaptureKit)");
}

}  // namespace gamepilot
