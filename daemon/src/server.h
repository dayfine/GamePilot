// The v1 JSON-RPC server and the frame loop. With a lockstep backend (mGBA) it
// is the daemon's one thread: between two emulator frames it serves the
// client; at each frame boundary it sets keys, steps the backend one frame,
// runs the subscribed probes on that frame and sends the results that changed
// since the client's previous frame. With a live backend (the Switch) it is the
// server thread of two: it takes each captured frame from the backend's ring,
// probes it the same way, and hands timed key segments to the controller when
// they are due.
//
// One client at a time. A second connection is an observer: it may only ask
// for `status`, so `gamepilot status` works while a program runs.
//
// With a watch page (ServerOptions::watch, server_watch.cpp) the loop also
// serves its HTTP connections: the frame, the probes and the health from here,
// the plan and log the program sends as notifications, and Stop.

#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "backend.h"
#include "clock.h"
#include "live_schedule.h"
#include "net.h"
#include "probe_evaluation.h"
#include "rpc.h"
#include "schedule.h"
#include "sent_results.h"
#include "template_store.h"
#include "watch_server.h"

namespace gamepilot {

struct ServerOptions {
  std::uint16_t port = 47900;
  bool fast =
      false;  // step as fast as the backend goes instead of at its frame rate
  std::string log_path;               // wire log; empty = none
  std::optional<WatchOptions> watch;  // the watch page; none = off
};

// What the watch page costs the frame loop, reported with the frame rate.
struct WatchCost {
  std::int64_t frames_encoded = 0;
  std::int64_t frame_bytes = 0;  // all frames encoded, in bytes
  double ms = 0;  // encoding frames and sending events
};

class Server {
 public:
  Server(Backend& backend, ServerOptions options);

  // Serves until `stop` turns true. Throws BackendError if the backend fails
  // mid-frame.
  void run(const std::atomic<bool>& stop);

  // The watch page's port, or 0 without one.
  std::uint16_t watch_port() const;

 private:
  void run_lockstep(const std::atomic<bool>& stop);
  void run_live(const std::atomic<bool>& stop);
  void serve_network(int timeout_ms);
  void accept_pending();
  void read_client();
  void read_observer();
  void drop_client(const char* reason);
  void handle_line(const std::string& line);
  void handle_observer_line(const std::string& line);
  DaemonStatus status() const;
  void send_probe_results(std::int64_t seq, double t_ms);
  pa::JsonObject dispatch(const Request& request);
  void send(const pa::JsonValue& message);
  void log(const char* dir, const pa::JsonValue& message);
  void step_frame();
  void rebase_pacing();

  // The watch page (server_watch.cpp).
  void start_watch();
  bool take_watch_note(const pa::JsonValue& message);
  bool stop_program();
  WatchFrame watch_frame();
  void watch_tick();
  void show_probes(
      std::int64_t seq,
      const std::vector<std::pair<std::string, ProbeResult>>& results);

  Backend& backend_;
  ServerOptions options_;
  Clock clock_;
  Socket listener_;
  Socket client_;
  LineBuffer client_lines_;
  std::optional<std::string> client_name_;  // from its hello
  Socket observer_;
  LineBuffer observer_lines_;
  pa::FileIO wire_log_;

  std::vector<FrameProbe> probes_;
  // Results sent since the last subscribe or load: a frame sends only the
  // ones that changed, the first frame after either sends all.
  SentResults sent_results_;
  TemplateStore templates_;
  InputSchedule schedule_;      // lockstep
  LiveSchedule live_schedule_;  // live
  std::optional<KeyMask> sent_mask_;

  // The server loop's heartbeat: the last frame it handled and when it last
  // went round.
  ThreadBeat beat_{"server", 0, 0};

  double pace_base_ms_ = 0;
  std::int64_t pace_base_seq_ = 0;
  std::int64_t frames_stepped_ = 0;
  std::int64_t loads_ = 0;  // successful backend.load_state calls

  std::unique_ptr<WatchServer> watch_;
  cv::Mat probed_frame_;  // the frame the probes last ran on
  std::int64_t probed_seq_ = -1;
  WatchFrame frame_shown_;  // the last frame sent to the page
  double frame_shown_ms_ = -1e9;
  double probes_shown_ms_ = -1e9;
  bool probes_shown_ = false;  // the page shows a non-empty probe list
  double status_shown_ms_ = -1e9;
  WatchCost watch_cost_;
};

}  // namespace gamepilot
