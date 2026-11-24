// The Switch's frame source: a capture card, or a recorded video played back at
// its own frame rate. Both read through OpenCV's VideoCapture. The C++ app's
// capture (CommonFramework/VideoPipeline/Backends, Qt Multimedia) is not
// reused; its format choice is: the configured resolution if the card offers
// it, else the first of 3840x2160, 1920x1080, 2560x1440, 1280x720, at the
// highest frame rate (QFormatAggregator.cpp, build_format_set). OpenCV cannot
// list a card's formats, so here the resolution, rate and pixel format are
// requested from the config and the card's answer is read back.

#pragma once

#include <memory>
#include <optional>
#include <opencv2/core.hpp>
#include <opencv2/videoio.hpp>
#include <string>

#include "clock.h"
#include "view_source.h"

namespace gamepilot {

class FrameSource {
 public:
  virtual ~FrameSource() = default;

  // Blocks until the next frame (BGR) and writes it to `frame`. Returns false
  // when the source has ended or failed.
  virtual bool read(cv::Mat& frame) = 0;

  // Frames per second the source delivers.
  virtual double frame_rate() const = 0;

  // Whether what it captures can be seen, for a source that can tell (a
  // window: covered, hidden); nothing for the others.
  virtual std::optional<SourceStatus> visibility() { return std::nullopt; }
};

struct CaptureCardConfig {
  // A device index ("0") or a name or path OpenCV opens as is.
  std::string device;
  int width = 1920;
  int height = 1080;
  double frame_rate = 60;
  // Four characters, e.g. "MJPG"; empty leaves the card's default.
  std::string fourcc;
};

// Opens the capture card. Throws BackendError if it does not open.
std::unique_ptr<FrameSource> open_capture_card(const CaptureCardConfig& config);

// Opens a recorded video and plays it at its own frame rate: each frame is
// returned no earlier than its time from the first read. Throws BackendError if
// the file does not open.
std::unique_ptr<FrameSource> open_video_replay(const std::string& path,
                                               const Clock& clock);

}  // namespace gamepilot
