#include "watch_hub.h"

#include <algorithm>
#include <stdexcept>
#include <utility>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "rpc.h"

namespace gamepilot {

namespace {

// How long one poll waits before the loop checks `stop` again.
constexpr int kPollMs = 200;
// A browser that does not take a whole response in this long is dropped.
constexpr int kSendTimeoutMs = 1000;
// What one read from a run takes at most: an MJPEG part of a 1280 px frame is
// about 115 KB, so a frame takes two reads.
constexpr std::size_t kReadChunk = 64 * 1024;
// While this much from a run waits for the browser, the hub stops reading the
// run, so the run sees a slow viewer and drops frames for it (about two
// frames: more would only add delay).
constexpr std::size_t kMaxPending = 256 * 1024;
// Recent finished runs /recent.json lists.
constexpr std::size_t kRecentRuns = 20;
// How often the "no live run" page looks again.
constexpr int kWaitRefreshS = 5;

constexpr std::string_view kRunsPrefix = "/runs/";
constexpr std::string_view kLive = "/live";
constexpr std::string_view kAnyOrigin = "Access-Control-Allow-Origin: *\r\n";

std::string folder_name(const std::string& path) {
  const std::size_t slash = path.find_last_of("/\\");
  return slash == std::string::npos ? path : path.substr(slash + 1);
}

std::string html_escape(std::string_view text) {
  std::string out;
  for (const char c : text) {
    switch (c) {
      case '&':
        out += "&amp;";
        break;
      case '<':
        out += "&lt;";
        break;
      case '>':
        out += "&gt;";
        break;
      case '"':
        out += "&quot;";
        break;
      default:
        out += c;
    }
  }
  return out;
}

// A short page for a run that is not live, or no live run: it links to the
// hub and to the newest live run and, with `refresh`, looks again by itself.
std::string notice_page(std::string_view text, bool refresh) {
  std::string page =
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
      "<meta name=\"viewport\" content=\"width=device-width, "
      "initial-scale=1\">";
  if (refresh) {
    page += "<meta http-equiv=\"refresh\" content=\"" +
            std::to_string(kWaitRefreshS) + "\">";
  }
  page +=
      "<title>GamePilot Runs</title><style>body{font:15px/1.5 -apple-system,"
      "sans-serif;margin:2em 16px;color:#1c2026;background:#f6f7f9}"
      "@media(prefers-color-scheme:dark){body{color:#e6e9ed;"
      "background:#14171b}a{color:#6aa8ff}}</style></head><body><p>";
  page += html_escape(text);
  page +=
      "</p><p><a href=\"/live\">Newest live run</a> &middot; <a href=\"/\">"
      "All runs</a></p></body></html>";
  return page;
}

// The newest live entry, of `checkpoint` when it is not empty.
const RegistryEntry* newest(const std::vector<RegistryEntry>& entries,
                            std::string_view checkpoint) {
  const RegistryEntry* best = nullptr;
  for (const RegistryEntry& entry : entries) {
    if ((checkpoint.empty() || entry.checkpoint == checkpoint) &&
        (best == nullptr || entry.started_ms > best->started_ms)) {
      best = &entry;
    }
  }
  return best;
}

std::string redirect(std::string_view location) {
  return http_response(302, "text/plain", "",
                       "Location: " + std::string(location) + "\r\n");
}

std::string with_query(std::string path, std::string_view query) {
  if (!query.empty()) {
    path += "?";
    path += query;
  }
  return path;
}

std::vector<std::string> split(std::string_view line, char separator) {
  std::vector<std::string> fields;
  while (true) {
    const std::size_t end = line.find(separator);
    fields.emplace_back(line.substr(0, end));
    if (end == std::string_view::npos) {
      return fields;
    }
    line.remove_prefix(end + 1);
  }
}

}  // namespace

std::string hub_run_name(const RegistryEntry& entry) {
  const std::string name = folder_name(entry.run_folder);
  return name.empty() ? "pid-" + std::to_string(entry.pid) : name;
}

std::string hub_runs_json(const std::vector<RegistryEntry>& entries) {
  pa::JsonArray list;
  for (const RegistryEntry& entry : entries) {
    pa::JsonObject run;
    run["pid"] = entry.pid;
    run["port"] = static_cast<std::int64_t>(entry.port);
    run["backend"] = entry.backend;
    run["run"] = hub_run_name(entry);
    run["checkpoint"] = entry.checkpoint;
    run["started_ms"] = entry.started_ms;
    list.push_back(std::move(run));
  }
  return to_line(pa::JsonValue(std::move(list)));
}

std::string hub_recent_json(std::string_view results_tsv, std::size_t limit) {
  std::vector<std::string> lines = split(results_tsv, '\n');
  for (std::string& line : lines) {
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
  }
  std::erase_if(lines, [](const std::string& line) { return line.empty(); });
  pa::JsonArray list;
  if (lines.empty()) {
    return to_line(pa::JsonValue(std::move(list)));
  }
  const std::vector<std::string> columns = split(lines[0], '\t');
  for (std::size_t i = lines.size() - 1; i >= 1 && list.size() < limit; i--) {
    const std::vector<std::string> fields = split(lines[i], '\t');
    pa::JsonObject row;
    for (std::size_t k = 0; k < columns.size() && k < fields.size(); k++) {
      row[columns[k]] = fields[k];
    }
    list.push_back(std::move(row));
  }
  return to_line(pa::JsonValue(std::move(list)));
}

WatchHub::WatchHub(HubOptions options)
    : options_(std::move(options)),
      listener_(listen_tcp(options_.listen, options_.port)) {}

void WatchHub::run(const std::atomic<bool>& stop) {
  while (!stop.load()) {
    serve_once(kPollMs);
  }
}

// The browser's socket is read for its request, then only to see it leave;
// the run's while the browser keeps up; the browser's is written to while
// something from the run waits for it.
void WatchHub::serve_once(int timeout_ms) {
  std::vector<PollWant> wants{PollWant{&listener_, true, false}};
  for (const Connection& connection : connections_) {
    const bool pending = connection.sent < connection.to_client.size();
    wants.push_back(PollWant{&connection.client, true, pending});
    wants.push_back(PollWant{&connection.upstream,
                             connection.to_client.size() < kMaxPending, false});
  }
  const std::vector<PollReady> ready = poll_sockets(wants, timeout_ms);
  for (std::size_t i = 0; i < connections_.size(); i++) {
    Connection& connection = connections_[i];
    const PollReady& client = ready[1 + 2 * i];
    const PollReady& upstream = ready[2 + 2 * i];
    if (client.readable) {
      read(connection);
    }
    if (upstream.readable) {
      pump(connection);
    }
    if (client.writable) {
      flush(connection);
    }
  }
  std::erase_if(connections_, [](const Connection& connection) {
    return !connection.client.valid();
  });
  if (ready[0].readable) {
    Socket socket = accept_client(listener_);
    if (socket.valid()) {
      set_send_timeout(socket, kSendTimeoutMs);
      const bool local = peer_is_loopback(socket);
      Connection connection;
      connection.client = std::move(socket);
      connection.local = local;
      connections_.push_back(std::move(connection));
    }
  }
}

void WatchHub::read(Connection& connection) {
  if (connection.proxying) {
    // Nothing more is expected from the browser: this only sees it leave.
    char buffer[512];
    if (!connection.client.receive_some(buffer, sizeof(buffer))) {
      connection.client.close();
      connection.upstream.close();
    }
    return;
  }
  const auto data = connection.client.receive_some();
  if (!data) {
    connection.client.close();
    return;
  }
  connection.request += *data;
  try {
    if (const auto request = take_request_head(connection.request)) {
      respond(connection, *request);
    }
  } catch (const std::invalid_argument&) {
    connection.client.send_all(
        http_response(400, "text/plain", "bad request\n"));
    connection.client.close();
  }
}

void WatchHub::respond(Connection& connection, const HttpRequest& request) {
  const std::string_view path = request.path;
  const bool get = request.method == "GET";
  std::string response;
  if (path.starts_with(kRunsPrefix)) {
    const std::string_view rest = path.substr(kRunsPrefix.size());
    const std::size_t slash = rest.find('/');
    const std::string name(rest.substr(0, slash));
    if (slash == std::string_view::npos) {
      response = redirect(with_query(std::string(path) + "/", request.query));
    } else {
      const auto entries = live_entries(options_.registry);
      const auto entry =
          std::find_if(entries.begin(), entries.end(),
                       [&](const RegistryEntry& e) {
                         return hub_run_name(e) == name;
                       });
      if (entry != entries.end()) {
        pass_through(connection, *entry, request, rest.substr(slash));
        return;
      }
      response =
          rest.substr(slash) == "/"
              ? http_response(404, "text/html; charset=utf-8",
                              notice_page("Run " + name +
                                              " is not live: it has ended "
                                              "or not started yet.",
                                          /*refresh=*/false))
              : http_response(404, "text/plain", "run not live\n");
    }
  } else if (!get) {
    response = http_response(405, "text/plain", "method not allowed\n");
  } else if (path == "/") {
    response = http_response(200, "text/html; charset=utf-8", hub_page());
  } else if (path == "/runs.json") {
    response = http_response(200, "application/json",
                             hub_runs_json(live_entries(options_.registry)),
                             kAnyOrigin);
  } else if (path == "/recent.json") {
    std::string tsv;
    if (!options_.results.empty()) {
      pa::file_to_string(options_.results, tsv);
    }
    response = http_response(200, "application/json",
                             hub_recent_json(tsv, kRecentRuns), kAnyOrigin);
  } else if (path == kLive || path == std::string(kLive) + "/" ||
             path.starts_with(std::string(kLive) + "/")) {
    const std::string_view checkpoint =
        path.size() > kLive.size() ? path.substr(kLive.size() + 1) : "";
    const auto entries = live_entries(options_.registry);
    const RegistryEntry* entry = newest(entries, checkpoint);
    response =
        entry != nullptr
            ? redirect(with_query(std::string(kRunsPrefix) +
                                      hub_run_name(*entry) + "/",
                                  request.query))
            : http_response(404, "text/html; charset=utf-8",
                            notice_page(checkpoint.empty()
                                            ? "No live run yet. This page "
                                              "looks again every few seconds."
                                            : "No live run of that checkpoint "
                                              "yet. This page looks again "
                                              "every few seconds.",
                                        /*refresh=*/true));
  } else {
    response = http_response(404, "text/plain", "not found\n");
  }
  connection.client.send_all(response);
  connection.client.close();
}

// The request goes on to the run with a head the hub writes itself (the
// browser's headers stay here, so it cannot claim to be local), then the
// run's answer streams back as it comes.
void WatchHub::pass_through(Connection& connection, const RegistryEntry& entry,
                            const HttpRequest& request, std::string_view path) {
  std::string head = request.method + " " +
                     with_query(std::string(path), request.query) +
                     " HTTP/1.1\r\nHost: 127.0.0.1:" +
                     std::to_string(entry.port) + "\r\n";
  if (!connection.local) {
    head += std::string(kViewerHeader) + ": " + std::string(kRemoteViewer) +
            "\r\n";
  }
  head += "\r\n";
  try {
    connection.upstream = connect_local(entry.port);
  } catch (const std::runtime_error&) {
    connection.client.send_all(
        http_response(502, "text/plain", "run not reachable\n"));
    connection.client.close();
    return;
  }
  if (!connection.upstream.send_all(head)) {
    connection.client.send_all(
        http_response(502, "text/plain", "run not reachable\n"));
    connection.client.close();
    connection.upstream.close();
    return;
  }
  set_nonblocking(connection.upstream);
  set_nonblocking(connection.client);
  connection.proxying = true;
}

void WatchHub::pump(Connection& connection) {
  char buffer[kReadChunk];
  while (connection.upstream.valid() &&
         connection.to_client.size() < kMaxPending) {
    const auto n = connection.upstream.receive_some(buffer, sizeof(buffer));
    if (!n) {
      connection.upstream.close();  // the run answered in full or left
      break;
    }
    if (*n == 0) {
      break;
    }
    connection.to_client.append(buffer, *n);
  }
  flush(connection);
}

void WatchHub::flush(Connection& connection) {
  std::string& pending = connection.to_client;
  while (connection.sent < pending.size()) {
    const auto n = connection.client.send_some(
        pending.data() + connection.sent, pending.size() - connection.sent);
    if (!n) {
      connection.client.close();
      connection.upstream.close();
      return;
    }
    if (*n == 0) {
      break;
    }
    connection.sent += *n;
  }
  if (connection.sent == pending.size()) {
    pending.clear();
    connection.sent = 0;
  } else if (connection.sent > pending.size() / 2) {
    pending.erase(0, connection.sent);
    connection.sent = 0;
  }
  if (connection.proxying && !connection.upstream.valid() && pending.empty()) {
    connection.client.close();
  }
}

}  // namespace gamepilot
