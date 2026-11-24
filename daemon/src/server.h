// The v1 JSON-RPC server and the frame loop. With a lockstep backend (mGBA) it
// is the daemon's one thread: between two emulator frames it serves the
// client; at each frame boundary it sets keys, steps the backend one frame,
// runs the subscribed probes on that frame and sends the results that changed
// since the client's previous frame. With a live backend (the Switch) it is the
// server thread of two: it takes each captured frame from the backend's ring,
// probes it the same way, and hands timed key segments to the controller when
// they are due.
//
// Any number of clients (up to kMaxClients). Each has its own probes,
// templates and frames; reads are served to all of them. Input (submit,
// cancel, backend.load_state) needs the input lease (input_lease.h): one
// connection at a time drives, the others watch or are refused.
//
// With a watch page (ServerOptions::watch, server_watch.cpp) the loop also
// serves its HTTP connections: the frame, the probes and the health from here,
// the plan and log the program sends as notifications, and Stop. With a run
// folder it keeps the notes there (run_journal.h) and, with `record`, records
// the run's frames on the stream's worker (frame_stream.h). With keep-awake
// on it presses a harmless key after a long idle (keep_awake.h). A view-only
// backend (view_backend.h) gets no input at all: the page also shows its
// picture's state and, with `tail_log`, another program's log.

#pragma once

#include <atomic>
#include <cstdint>
#include <deque>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "backend.h"
#include "clock.h"
#include "frame_stream.h"
#include "input_lease.h"
#include "keep_awake.h"
#include "log_tail.h"
#include "live_schedule.h"
#include "net.h"
#include "probe_evaluation.h"
#include "rpc.h"
#include "run_journal.h"
#include "schedule.h"
#include "sent_results.h"
#include "template_store.h"
#include "watch_registry.h"
#include "watch_server.h"

namespace gamepilot {

struct ServerOptions {
  std::uint16_t port = 47900;
  bool fast =
      false;  // step as fast as the backend goes instead of at its frame rate
  // A lockstep backend steps `speed` times its frame rate (ignored with
  // `fast`); frame and batch_done t_ms stay game time (server.cpp).
  double speed = 1;
  std::string log_path;               // wire log; empty = none
  std::optional<WatchOptions> watch;  // the watch page; none = off
  StreamOptions stream;               // its live frame
  // With a watch page: the registry folder its entry goes to (empty = none),
  // and what the entry says about the run.
  std::string registry;
  std::string checkpoint;
  // The run's folder: its notes (run_journal.h) and recorded frames go there;
  // empty = none.
  std::string run_folder;
  bool record = false;  // record frames into run_folder/frames
  KeepAwakeOptions keepawake;
  // A view-only source's registry name and label (watch_registry.h).
  std::string name;
  std::string source;
  // With a watch page: another program's log whose new lines go to the
  // page's log (log_tail.h); empty = none.
  std::string tail_log;
};

// Connections served at once; one more is refused.
constexpr std::size_t kMaxClients = 16;

// One client's connection and what it set up on it.
struct ClientConnection {
  int number = 0;  // from 1, in the order connections came
  Socket socket;
  LineBuffer lines;
  std::optional<std::string> name;  // from its hello
  std::vector<FrameProbe> probes;
  // Results sent since its last subscribe or a load: a frame sends only the
  // ones that changed, the first frame after either sends all.
  SentResults sent_results;
  TemplateStore templates;
};

// What the watch page costs the frame loop, reported with the frame rate.
struct WatchCost {
  std::int64_t frames_encoded = 0;
  std::int64_t frame_bytes = 0;  // all frames encoded, in bytes
  // Encoding /frame, sending events and handing frames to the stream (whose
  // encoding is on its own thread and reported by it).
  double ms = 0;
};

class Server {
 public:
  // `clock` is the daemon's one clock: a live backend stamps its frames on
  // it, and the server stamps batch ends, the wire log and the lease on it, so
  // a frame's t_ms and a batch_done's compare (console B, 2026-11-23: a clock
  // of the server's own started 524 ms after the backend's, and every wait
  // after a batch lost that much).
  Server(Backend& backend, ServerOptions options, const Clock& clock);

  // Serves until `stop` turns true. Throws BackendError if the backend fails
  // mid-frame.
  void run(const std::atomic<bool>& stop);

  // The program's port (`options.port`, or the one picked for 0).
  std::uint16_t port() const { return local_port(listener_); }
  // The watch page's port, or 0 without one.
  std::uint16_t watch_port() const;
  // Stop's token on the watch page, empty without one.
  std::string watch_token() const;

 private:
  void run_lockstep(const std::atomic<bool>& stop);
  double game_ms() const;
  void keep_awake();
  bool batch_pending() const;
  void send_batch_done(const std::string& batch_id, std::int64_t seq,
                       double t_ms);
  void run_live(const std::atomic<bool>& stop);
  void serve_network(int timeout_ms);
  void accept_pending();
  void read_client(ClientConnection& client);
  void drop_client(ClientConnection& client, const char* reason);
  void handle_line(ClientConnection& client, const std::string& line);
  std::optional<std::string> take_lease(ClientConnection& client,
                                        const std::string& method);
  void clear_input();
  // The connection whose probes the watch page shows: the oldest with any.
  const ClientConnection* watched_client() const;
  DaemonStatus status() const;
  void send_probe_results(std::int64_t seq, double t_ms);
  pa::JsonObject dispatch(ClientConnection& client, const Request& request);
  pa::JsonObject dispatch_probes(ClientConnection& client,
                                 const Request& request);
  pa::JsonObject dispatch_input(ClientConnection& client,
                                const Request& request);
  void send(ClientConnection& client, const pa::JsonValue& message);
  void log(const char* dir, const pa::JsonValue& message,
           std::optional<int> conn = std::nullopt,
           const std::optional<std::string>& owner = std::nullopt);
  void step_frame();
  void rebase_pacing();

  // The watch page (server_watch.cpp).
  void start_watch();
  bool take_watch_note(const pa::JsonValue& message);
  bool stop_program();
  WatchFrame watch_frame();
  void offer_stream_frame();
  void watch_tick();
  void show_source();
  void tail_log();
  FrameStream* stream();
  void note_plan(const pa::JsonObject& plan);
  void mark_failure();
  void show_probes(
      std::int64_t seq, const std::vector<FrameProbe>& probes,
      const std::vector<std::pair<std::string, ProbeResult>>& results);

  Backend& backend_;
  ServerOptions options_;
  const Clock& clock_;
  Socket listener_;
  std::vector<std::unique_ptr<ClientConnection>> clients_;
  int connections_ = 0;  // connections accepted so far
  pa::FileIO wire_log_;

  InputLease lease_;
  // Submitted batches not yet done, in order: id and connection number, so
  // each batch_done goes to the client that submitted it.
  std::deque<std::pair<std::string, int>> batch_owners_;
  InputSchedule schedule_;      // lockstep
  LiveSchedule live_schedule_;  // live
  std::optional<KeyMask> sent_mask_;

  // The server loop's heartbeat: the last frame it handled and when it last
  // went round.
  ThreadBeat beat_{"server", 0, 0};

  double pace_base_ms_ = 0;
  std::int64_t pace_base_seq_ = 0;
  std::int64_t frames_stepped_ = 0;
  double game_zero_ms_ = 0;
  std::int64_t loads_ = 0;  // successful backend.load_state calls

  std::unique_ptr<WatchServer> watch_;
  std::optional<RegistryFile> registry_entry_;  // while the page is up
  cv::Mat probed_frame_;  // the frame the probes last ran on
  std::int64_t probed_seq_ = -1;
  WatchFrame frame_shown_;  // the last frame sent to the page
  double frame_shown_ms_ = -1e9;
  double probes_shown_ms_ = -1e9;
  bool probes_shown_ = false;  // the page shows a non-empty probe list
  double status_shown_ms_ = -1e9;
  WatchCost watch_cost_;
  std::optional<SourceStatus> source_shown_;
  cv::Size info_shown_;  // the frame size the page's `info` gives
  double source_checked_ms_ = -1e9;
  std::optional<LogTail> log_tail_;
  double log_polled_ms_ = -1e9;

  std::optional<RunJournal> journal_;  // with a run folder
  // The stream's worker for recording when there is no watch page.
  std::unique_ptr<FrameStream> record_stream_;
  PlanStep step_;  // the plan's current event, for recorded frames
  double failure_marked_ms_ = -1e9;
  KeepAwake keep_awake_;
};

}  // namespace gamepilot
