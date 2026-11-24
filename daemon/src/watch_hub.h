// The hub: one page at a fixed port (47901) that lists the live runs from the
// watch registry (watch_registry.h) and serves each run's own page under a
// path named for the run, so a run's URL is readable and on the same port. It
// is the daemon started with `--hub`, no backend, serving only HTTP with the
// same pieces as the watch page (http.h, net.h):
//
//   GET /              the page (watch/hub.html, compiled in): the live runs,
//                      each with its checkpoint, mode and trial (from the
//                      run's /summary.json), elapsed time and state; then
//                      every run in the runs folder, with filters kept in the
//                      URL's query (Watch-Page.md, Runs list)
//   GET /runs.json     the live registry entries
//   GET /recent.json   the latest finished runs (RESULTS.tsv), newest first
//   GET /history.json  every run folder (run_history.h), newest first
//   GET /runs/NAME/    the run's page from the hub's own build: the live page
//                      (watch/watch.html) while the run is live, with the
//                      token the run gives its local viewers; the page of a
//                      finished run (watch/run.html) after
//   GET /runs/NAME/record.json, /probes.json, /files/PATH
//                      a run's row, its probe timeline (from wire.jsonl, read
//                      a chunk at a time and kept while the file is
//                      unchanged), and its folder's servable files
//                      (run_history.h: notes, log, failure frame, recorded
//                      frames)
//   /runs/NAME/...     anything else while the run is live goes to its port:
//                      /events, /stream, /frame, /summary.json and
//                      POST /stop?token=T. NAME is the run folder's name.
//                      Only data comes from the run, so a page from the
//                      hub's newer build works with an older run daemon.
//   GET /live          redirects to the newest live run's page; /live/CP to
//                      the newest live run of checkpoint CP. With none, a page
//                      that looks again every few seconds. External sources
//                      (an entry with a `source`: a view-only daemon watching
//                      another program) are listed but never /live.
//
// Passing a run through streams it: what the run sends goes to the browser as
// it comes (no buffering of the event stream or the MJPEG stream), and a
// browser that does not take it holds the run's socket, so the run drops
// frames for it as it does for a slow direct viewer.
//
// The runner starts it when nothing listens on its port, so one runs per
// machine; a second one finds the port taken and exits.

#pragma once

#include <atomic>
#include <cstdint>
#include <map>
#include <utility>
#include <string>
#include <string_view>
#include <vector>

#include "http.h"
#include "net.h"
#include "watch_registry.h"

namespace gamepilot {

struct HubOptions {
  std::string listen = "127.0.0.1";
  std::uint16_t port = 47901;
  std::string registry;  // the registry folder
  std::string results;   // the runs' RESULTS.tsv; empty = none
  std::string runs;      // the runs folder; empty = none
};

// A run's name in its hub path: the entry's `name` (a view-only source's),
// else its folder's name, else pid-N.
std::string hub_run_name(const RegistryEntry& entry);

// The entries as /runs.json gives them: the run folder's name only, so its
// path stays on this machine.
std::string hub_runs_json(const std::vector<RegistryEntry>& entries);

// RESULTS.tsv's last `limit` rows, newest first, as /recent.json gives them:
// one object per row keyed by the header's column names.
std::string hub_recent_json(std::string_view results_tsv, std::size_t limit);

class WatchHub {
 public:
  // Throws std::runtime_error when it cannot listen.
  explicit WatchHub(HubOptions options);

  std::uint16_t port() const { return local_port(listener_); }

  // Serves until `stop` turns true.
  void run(const std::atomic<bool>& stop);
  // Waits up to `timeout_ms` for sockets, then serves what is ready.
  void serve_once(int timeout_ms);

 private:
  struct Connection {
    Socket client;
    std::string request;
    bool local = false;      // the browser is on this machine
    Socket upstream;         // the run's page, once passed through
    std::string to_client;   // from the run, not yet taken by the browser
    std::size_t sent = 0;    // of to_client
    bool proxying = false;
    // Passing the run's page: it is kept whole for its token, then this
    // build's page goes to the browser in its place.
    bool page = false;
  };

  void read(Connection& connection);
  void respond(Connection& connection, const HttpRequest& request);
  // A /runs/NAME/... request; false when it goes on to the live run.
  bool respond_run(Connection& connection, const HttpRequest& request,
                   const std::string& name, std::string_view rest,
                   const RegistryEntry* live);
  std::string probe_timeline(const std::string& name);
  std::string results_text() const;
  void pass_through(Connection& connection, const RegistryEntry& entry,
                    const HttpRequest& request, std::string_view path);
  void pump(Connection& connection);
  void flush(Connection& connection);

  HubOptions options_;
  Socket listener_;
  std::vector<Connection> connections_;
  // Probe timelines by run, with the wire log's size they were read at.
  std::map<std::string, std::pair<std::uintmax_t, std::string>> timelines_;
};

// The page, compiled in from watch/hub.html (hub_page.cpp is generated).
std::string_view hub_page();
// A finished run's page, from watch/run.html (run_page.cpp is generated).
std::string_view run_page();

}  // namespace gamepilot
