#include "watch_hub.h"

#include <stdexcept>
#include <utility>

#include "http.h"
#include "rpc.h"

namespace gamepilot {

namespace {

// How long one poll waits before the loop checks `stop` again.
constexpr int kPollMs = 200;
// A browser that does not take the response in this long is dropped.
constexpr int kSendTimeoutMs = 1000;

std::string folder_name(const std::string& path) {
  const std::size_t slash = path.find_last_of("/\\");
  return slash == std::string::npos ? path : path.substr(slash + 1);
}

}  // namespace

std::string hub_runs_json(const std::vector<RegistryEntry>& entries) {
  pa::JsonArray list;
  for (const RegistryEntry& entry : entries) {
    pa::JsonObject run;
    run["pid"] = entry.pid;
    run["port"] = static_cast<std::int64_t>(entry.port);
    run["backend"] = entry.backend;
    run["run"] = folder_name(entry.run_folder);
    run["checkpoint"] = entry.checkpoint;
    run["started_ms"] = entry.started_ms;
    list.push_back(std::move(run));
  }
  return to_line(pa::JsonValue(std::move(list)));
}

WatchHub::WatchHub(HubOptions options)
    : options_(std::move(options)),
      listener_(listen_tcp(options_.listen, options_.port)) {}

void WatchHub::run(const std::atomic<bool>& stop) {
  while (!stop.load()) {
    std::vector<const Socket*> sockets{&listener_};
    for (const Connection& connection : connections_) {
      sockets.push_back(&connection.socket);
    }
    serve(poll_readable(sockets, kPollMs));
  }
}

void WatchHub::serve(const std::vector<bool>& readable) {
  for (std::size_t i = 0; i < connections_.size(); i++) {
    if (i + 1 < readable.size() && readable[i + 1]) {
      read(connections_[i]);
    }
  }
  std::erase_if(connections_, [](const Connection& connection) {
    return !connection.socket.valid();
  });
  if (!readable.empty() && readable[0]) {
    Socket socket = accept_client(listener_);
    if (socket.valid()) {
      set_send_timeout(socket, kSendTimeoutMs);
      connections_.push_back(Connection{std::move(socket), {}});
    }
  }
}

void WatchHub::read(Connection& connection) {
  const auto data = connection.socket.receive_some();
  if (!data) {
    connection.socket.close();
    return;
  }
  connection.request += *data;
  std::string response;
  try {
    const auto request = take_request_head(connection.request);
    if (!request) {
      return;
    }
    if (request->method != "GET") {
      response = http_response(405, "text/plain", "method not allowed\n");
    } else if (request->path == "/") {
      response = http_response(200, "text/html; charset=utf-8", hub_page());
    } else if (request->path == "/runs.json") {
      response = http_response(200, "application/json",
                               hub_runs_json(live_entries(options_.registry)));
    } else {
      response = http_response(404, "text/plain", "not found\n");
    }
  } catch (const std::invalid_argument&) {
    response = http_response(400, "text/plain", "bad request\n");
  }
  connection.socket.send_all(response);
  connection.socket.close();
}

}  // namespace gamepilot
