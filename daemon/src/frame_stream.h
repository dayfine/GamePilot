// The watch page's live frame: an MJPEG stream (multipart/x-mixed-replace) to
// each viewer's <img>, encoded on a thread of its own so the frame loop only
// hands over the frame.
//
// The loop asks `wants_frame` each pass and, when it says yes, `offer`s the
// current frame: that is at most `fps` times a second and only while a viewer
// is connected, so without one nothing is read or encoded. The worker encodes
// the latest frame offered once per width the viewers asked for, shared by
// all of them, and sends it to every viewer that has taken the previous one.
// A viewer still taking an older frame skips the new one: frames are dropped,
// never queued, so a slow viewer gets fewer frames and costs nothing else.

#pragma once

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <opencv2/core.hpp>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

#include "clock.h"
#include "net.h"

namespace gamepilot {

struct StreamOptions {
  double fps = 30;   // frames a second at most, per viewer
  int width = 1280;  // a large frame is scaled down to this width
};

// The widths a viewer may ask for (`/stream?w=`), rounded down to a multiple
// of 32 so a few viewers share an encoding.
constexpr int kStreamMinWidth = 320;
constexpr int kStreamMaxWidth = 1920;
// More viewers than this are refused: each width is an encoding.
constexpr int kStreamMaxViewers = 8;

// One frame as the stream sends it, JPEG. A small frame (the GBA's 240x160) is
// doubled with nearest-neighbour pixels and kept at full colour resolution
// (4:4:4) at high quality, so pixel art stays sharp: MJPEG cannot carry PNG.
// A larger one is scaled down to `width` (never up).
std::string encode_stream_frame(const cv::Mat& frame, int width);

// The width a viewer gets for its `?w=` (empty or bad = `fallback`).
int stream_width(std::string_view asked, int fallback);

class FrameStream {
 public:
  explicit FrameStream(StreamOptions options);
  ~FrameStream();
  FrameStream(const FrameStream&) = delete;
  FrameStream& operator=(const FrameStream&) = delete;

  // A viewer that has had the stream's head; the stream owns it from now on.
  // False (and the socket is closed) when there are too many. On the frame
  // loop's thread, like `wants_frame` and `offer`.
  bool add_viewer(Socket socket, int width);
  int viewers() const { return viewer_count_.load(); }

  // On the frame loop's thread: whether to offer frame `seq` now (a viewer is
  // connected, it is a new frame and the last offer is a frame interval old).
  bool wants_frame(std::int64_t seq, double now_ms) const;
  // Hands the frame over (shared, not copied: the caller must not write to
  // it afterwards) and wakes the worker. A frame not yet encoded is replaced.
  void offer(const cv::Mat& frame, std::int64_t seq, double now_ms);

 private:
  struct Viewer {
    Socket socket;
    int width = 0;
    std::shared_ptr<const std::string> sending;  // the part being sent
    std::size_t sent = 0;                         // bytes of it sent
    std::int64_t seq = -1;                        // the last frame taken
    double progress_ms = 0;  // when it last took a byte
    std::int64_t frames = 0;  // taken since `since_ms`
    double since_ms = 0;
  };

  void work();
  int part_key(int width) const;
  void encode(const cv::Mat& frame, std::int64_t seq);
  // Sends what each viewer can take now; drops the ones that are gone.
  // Returns whether any is still in the middle of a frame.
  bool send_to_viewers();
  void report(double now_ms);

  const StreamOptions options_;
  Clock clock_;  // the worker's, for its report and stalled viewers
  // The frame loop's.
  double offered_ms_ = -1e9;
  std::int64_t offered_seq_ = -1;

  std::mutex mutex_;
  std::condition_variable wake_;
  bool quit_ = false;
  cv::Mat latest_;
  std::int64_t latest_seq_ = -1;
  bool fresh_ = false;
  std::vector<Viewer> joining_;
  std::atomic<int> viewer_count_{0};  // joining and joined

  // The worker's own.
  std::vector<Viewer> viewers_;
  std::map<int, std::shared_ptr<const std::string>> parts_;  // by width
  std::int64_t parts_seq_ = -1;
  int frame_cols_ = 0;  // the width of the frame they were encoded from
  double report_ms_ = 0;
  std::int64_t encoded_ = 0;
  double encode_ms_ = 0;
  std::int64_t encoded_bytes_ = 0;

  std::thread worker_;
};

}  // namespace gamepilot
