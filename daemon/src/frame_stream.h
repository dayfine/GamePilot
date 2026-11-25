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
//
// The same worker records the run when asked (`record_to`): a 640-wide JPEG
// every second, plus one at each mark (a story step, a failure), into the run
// folder's frames/, with frames/index.jsonl (one line per frame: its file,
// seq, daemon-clock and Unix time, the step and why it was taken). The frame
// loop only hands the frame over, as for a viewer.

#pragma once

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
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

struct RecordOptions {
  std::string dir;  // the run's frames/ folder; created when missing
  double every_ms = 1000;
  int width = 640;
  // Unix ms at the daemon clock's 0, for the index's `unix_ms`.
  double clock_zero_unix_ms = 0;
};

// Why a recorded frame was taken.
constexpr std::string_view kRecordTick = "tick";
constexpr std::string_view kRecordStep = "step";
constexpr std::string_view kRecordFailure = "failure";

// One line of frames/index.jsonl.
struct RecordedFrame {
  std::int64_t n = 0;  // 1, 2, ...: the file is <n, 6 digits>.jpg
  std::int64_t seq = 0;
  double t_ms = 0;  // daemon clock
  double unix_ms = 0;
  std::string step;
  std::string why;
  std::int64_t bytes = 0;
};
std::string recorded_frame_json(const RecordedFrame& frame);
std::string recorded_frame_file(std::int64_t n);

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

  // On the frame loop's thread, before any frame: records from now on.
  void record_to(RecordOptions options);
  bool recording() const { return record_.has_value(); }
  // On the frame loop's thread: the step the next recorded frames belong to,
  // and a mark that records the next frame offered (`why`: kRecordStep,
  // kRecordFailure). Nothing without recording.
  void set_step(std::string step) { step_ = std::move(step); }
  void mark(std::string_view why);

  // On the frame loop's thread: whether to offer frame `seq` now (a viewer is
  // connected, it is a new frame and the last offer is a frame interval old;
  // or a recorded frame is due).
  bool wants_frame(std::int64_t seq, double now_ms) const;
  // Hands the frame over (shared, not copied: the caller must not write to
  // it afterwards) and wakes the worker. A frame not yet encoded is replaced
  // (a recording it was due for moves to the new one).
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

  struct RecordJob {
    bool due = false;
    double t_ms = 0;
    std::string step;
    std::string why;
  };

  void work();
  void record(const cv::Mat& frame, std::int64_t seq, const RecordJob& job);
  void report_record(double now_ms);
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
  std::optional<RecordOptions> record_;  // set before the first frame
  double recorded_ms_ = -1e9;
  std::string step_;
  std::string mark_;  // a pending mark's why

  std::mutex mutex_;
  std::condition_variable wake_;
  bool quit_ = false;
  cv::Mat latest_;
  std::int64_t latest_seq_ = -1;
  bool fresh_ = false;
  RecordJob record_job_;  // for latest_
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
  std::int64_t recorded_n_ = 0;
  bool record_warned_ = false;
  double record_report_ms_ = 0;
  std::int64_t recorded_ = 0;  // since record_report_ms_
  double record_encode_ms_ = 0;
  std::int64_t recorded_bytes_ = 0;

  std::thread worker_;
};

}  // namespace gamepilot
