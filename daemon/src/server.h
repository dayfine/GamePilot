// The v1 JSON-RPC server and the frame loop. Single-threaded: between two
// emulator frames it serves the client; at each frame boundary it sets keys,
// steps the backend one frame, runs the subscribed probes on that frame and
// sends the results.

#pragma once

#include <atomic>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "backend.h"
#include "clock.h"
#include "net.h"
#include "rpc.h"
#include "schedule.h"
#include "template_store.h"

namespace gamepilot {

struct ServerOptions {
  std::uint16_t port = 47900;
  bool fast =
      false;  // step as fast as the backend goes instead of at its frame rate
  std::string log_path;  // wire log; empty = none
};

class Server {
 public:
  Server(Backend& backend, ServerOptions options);

  // Serves until `stop` turns true. Throws BackendError if the backend fails
  // mid-frame.
  void run(const std::atomic<bool>& stop);

 private:
  void serve_network(int timeout_ms);
  void accept_pending();
  void read_client();
  void drop_client(const char* reason);
  void handle_line(const std::string& line);
  pa::JsonObject dispatch(const Request& request);
  void check_probe(const ProbeSpec& probe) const;
  ProbeResult evaluate(const ProbeSpec& probe, const cv::Mat& frame) const;
  void send(const pa::JsonValue& message);
  void log(const char* dir, const pa::JsonValue& message);
  void step_frame();
  void rebase_pacing();

  Backend& backend_;
  ServerOptions options_;
  Clock clock_;
  Socket listener_;
  Socket client_;
  LineBuffer client_lines_;
  pa::FileIO wire_log_;

  std::vector<ProbeSpec> probes_;
  TemplateStore templates_;
  InputSchedule schedule_;
  std::optional<KeyMask> sent_mask_;

  double pace_base_ms_ = 0;
  std::int64_t pace_base_seq_ = 0;
  std::int64_t frames_stepped_ = 0;
  std::int64_t loads_ = 0;  // successful backend.load_state calls
};

}  // namespace gamepilot
