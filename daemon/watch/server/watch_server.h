// The watch page's HTTP server: the page itself, the current frame as an image,
// a Server-Sent Events stream of what the run is doing, and Stop. It runs
// inside the daemon's server loop (no thread of its own): the loop polls its
// sockets with the program's and calls `serve`.
//
//   GET  /           the page (watch/page/watch.html, compiled in)
//   GET  /NAME       its scripts and styles (watch_assets.h: watch.css,
//                    watch_frame.js, ...)
//   GET  /stream?w=W the live frame as MJPEG, up to W pixels wide
//                    (frame_stream.h); view-only, like the page
//   GET  /frame      the current frame, PNG or JPEG (hooks.frame): the page's
//                    fallback when the stream fails
//   GET  /events     the event stream: `info` (the backend, as `hello` gives
//                    it), `run`, `plan`, `source`, `log` (the backlog, then
//                    each line), `probes` and `status`; a new viewer gets the
//                    latest of each first
//   GET  /summary.json  the latest run and plan, and a view-only source's
//                    `source` state, for the hub's list (any origin may read
//                    it: the hub is on another port)
//   POST /stop?token=T  stops the running program (hooks.stop)
//
// Stop takes the run's token: a page served to this machine carries it, a page
// served to another one does not, so a LAN viewer watches read-only unless its
// URL has `?token=T` (the runner prints that URL). Through the hub, the hub's
// kViewerHeader says which kind of viewer asked.
//
// What the stream carries is the server's to set; this class only keeps the
// latest of each and sends it.

#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <functional>
#include <string>
#include <string_view>
#include <vector>

#include "frame_stream.h"
#include "http.h"
#include "net.h"

namespace gamepilot {

struct WatchOptions {
  std::string listen = "127.0.0.1";  // "0.0.0.0" opens the page to the LAN
  std::uint16_t port = 47901;        // 0 = any free port
  std::string token;                 // Stop's; empty = a new random one
};

// 32 random hex digits.
std::string new_watch_token();
// Whether `token` may be a watch token: 1 to 64 letters, digits, '-' or '_'
// (it goes into the page and URLs as it is).
bool valid_watch_token(std::string_view token);

// The page with Stop's token in its `gamepilot-token` meta tag; without one
// the page is read-only. The hub serves its own build of the page the same
// way, with the token the run put in the page it served the hub.
std::string page_with_token(std::string_view token);
// The token in a served page's meta tag; empty when it has none.
std::string page_token(std::string_view page);

// An encoded frame and its media type ("image/png", "image/jpeg").
struct WatchFrame {
  std::string type;
  std::string bytes;
};

struct WatchHooks {
  std::function<WatchFrame()> frame;  // the current frame, encoded
  std::function<bool()> stop;         // stops the program; false when none runs
};

// Log lines a new viewer gets.
constexpr std::size_t kWatchLogBacklog = 1000;
// A viewer that does not take an event in this long is dropped, so a stalled
// browser cannot hold up the frame loop.
constexpr int kWatchSendTimeoutMs = 100;

class WatchServer {
 public:
  // Throws std::runtime_error when it cannot listen.
  WatchServer(const WatchOptions& options, WatchHooks hooks,
              StreamOptions stream = {});

  std::uint16_t port() const { return local_port(listener_); }
  const std::string& token() const { return token_; }

  // The sockets to poll; `serve` takes the flags poll gave for them.
  std::vector<const Socket*> sockets() const;
  void serve(const std::vector<bool>& readable);

  // The live frame's stream: the frame loop offers it frames.
  FrameStream& stream() { return stream_; }

  // Whether a page has the event stream open.
  bool has_viewers() const;
  // Whether a viewer joined since the last call (it has no status yet).
  bool take_joined();

  // Each is one line of JSON, kept for new viewers and sent to the others.
  void set_info(std::string json);
  void set_run(std::string json);
  void set_plan(std::string json);
  // A view-only source's picture state (view_source.h); also in
  // /summary.json once set.
  void set_source(std::string json);
  void add_log(std::string json);
  void set_probes(std::string json);
  // Sent to the viewers and not kept.
  void broadcast(std::string_view event, std::string_view json);

 private:
  struct Connection {
    Socket socket;
    std::string request;
    bool streaming = false;
    bool local = false;  // the peer is on this machine
  };

  void accept_viewer();
  void read(Connection& connection);
  void respond(Connection& connection, const HttpRequest& request);
  void start_stream(Connection& connection);
  void start_frame_stream(Connection& connection, const HttpRequest& request);
  void stop(Connection& connection, const HttpRequest& request);
  void send(Connection& connection, const std::string& data);

  Socket listener_;
  std::string token_;
  WatchHooks hooks_;
  std::vector<Connection> connections_;
  std::string info_;
  std::string run_;
  std::string plan_;
  std::string source_;
  std::string probes_;
  std::deque<std::string> log_;
  bool joined_ = false;
  StreamOptions stream_options_;
  FrameStream stream_;
};

// The page, compiled in from watch/page/watch.html (watch_page.cpp is
// generated).
std::string_view watch_page();

}  // namespace gamepilot
