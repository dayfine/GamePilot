// A frame source that captures one app window (macOS ScreenCaptureKit), for
// the view backend (view_backend.h): another program's picture shown on the
// watch page with nothing sent to its console. Only what the window server
// already composed is read; the app is never focused, raised or moved.
//
// The window is the largest normal window of the app (by pid, or by its
// bundle's path) whose title contains `title`. Frames come at most
// `frame_rate` a second; when the window does not change, ScreenCaptureKit
// sends none, and read() repeats the last frame so the stream and the stale
// detector keep going. A window fully covered by another normal window is not
// repainted by its app (Qt stops painting it), so its frames freeze: the
// source then reports it covered (visibility()), checked once a second from
// the window list.
//
// Other platforms build without it: open_window_capture throws there.

#pragma once

#include <cstdint>
#include <memory>
#include <string>

#include "video_capture.h"

namespace gamepilot {

struct WindowCaptureConfig {
  std::int64_t pid = 0;  // 0 = find the app by `app_path`
  std::string app_path;  // its bundle, e.g. /Applications/X/X.app
  std::string title;     // a part of the window's title; empty = any
  double frame_rate = 30;
};

// Throws BackendError when the window is not found, capture is not allowed
// (Screen Recording) or the platform has no window capture.
std::unique_ptr<FrameSource> open_window_capture(
    const WindowCaptureConfig& config);

}  // namespace gamepilot
