#include "watch_server.h"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace gamepilot {

WatchServer::WatchServer(const WatchOptions& options, WatchHooks hooks)
    : listener_(listen_tcp(options.listen, options.port)),
      hooks_(std::move(hooks)) {}

std::vector<const Socket*> WatchServer::sockets() const {
  std::vector<const Socket*> sockets{&listener_};
  for (const Connection& connection : connections_) {
    sockets.push_back(&connection.socket);
  }
  return sockets;
}

void WatchServer::serve(const std::vector<bool>& readable) {
  for (std::size_t i = 0; i < connections_.size(); i++) {
    if (i + 1 < readable.size() && readable[i + 1]) {
      read(connections_[i]);
    }
  }
  std::erase_if(connections_, [](const Connection& connection) {
    return !connection.socket.valid();
  });
  if (!readable.empty() && readable[0]) {
    accept_viewer();
  }
}

bool WatchServer::has_viewers() const {
  return std::any_of(connections_.begin(), connections_.end(),
                     [](const Connection& connection) {
                       return connection.streaming && connection.socket.valid();
                     });
}

bool WatchServer::take_joined() {
  const bool joined = joined_;
  joined_ = false;
  return joined;
}

void WatchServer::accept_viewer() {
  Socket socket = accept_client(listener_);
  if (socket.valid()) {
    set_send_timeout(socket, kWatchSendTimeoutMs);
    connections_.push_back(Connection{std::move(socket), {}, false});
  }
}

void WatchServer::read(Connection& connection) {
  const auto data = connection.socket.receive_some();
  if (!data) {
    connection.socket.close();
    return;
  }
  if (connection.streaming) {
    return;  // nothing more is expected from a viewer
  }
  connection.request += *data;
  try {
    if (const auto request = take_request_head(connection.request)) {
      respond(connection, *request);
    }
  } catch (const std::invalid_argument&) {
    send(connection, http_response(400, "text/plain", "bad request\n"));
    connection.socket.close();
  }
}

void WatchServer::respond(Connection& connection, const HttpRequest& request) {
  const bool get = request.method == "GET";
  if (get && request.path == "/events") {
    start_stream(connection);
    return;
  }
  if (get && request.path == "/") {
    send(connection,
         http_response(200, "text/html; charset=utf-8", watch_page()));
  } else if (get && request.path == "/frame.jpg") {
    send(connection, http_response(200, "image/jpeg", hooks_.frame_jpeg()));
  } else if (request.method == "POST" && request.path == "/stop") {
    const bool stopped = hooks_.stop();
    send(connection,
         http_response(200, "application/json",
                       stopped ? "{\"stopped\":true}" : "{\"stopped\":false}"));
  } else if (request.path == "/stop" || request.path == "/" ||
             request.path == "/frame.jpg" || request.path == "/events") {
    send(connection, http_response(405, "text/plain", "method not allowed\n"));
  } else {
    send(connection, http_response(404, "text/plain", "not found\n"));
  }
  connection.socket.close();
}

void WatchServer::start_stream(Connection& connection) {
  connection.streaming = true;
  joined_ = true;
  std::string snapshot = event_stream_head();
  if (!info_.empty()) {
    snapshot += event_message("info", info_);
  }
  if (!plan_.empty()) {
    snapshot += event_message("plan", plan_);
  }
  for (const std::string& line : log_) {
    snapshot += event_message("log", line);
  }
  if (!probes_.empty()) {
    snapshot += event_message("probes", probes_);
  }
  send(connection, snapshot);
}

void WatchServer::send(Connection& connection, const std::string& data) {
  if (connection.socket.valid() && !connection.socket.send_all(data)) {
    connection.socket.close();
  }
}

void WatchServer::broadcast(std::string_view event, std::string_view json) {
  const std::string message = event_message(event, json);
  for (Connection& connection : connections_) {
    if (connection.streaming) {
      send(connection, message);
    }
  }
}

void WatchServer::set_info(std::string json) {
  info_ = std::move(json);
  broadcast("info", info_);
}

void WatchServer::set_plan(std::string json) {
  plan_ = std::move(json);
  broadcast("plan", plan_);
}

void WatchServer::add_log(std::string json) {
  broadcast("log", json);
  log_.push_back(std::move(json));
  if (log_.size() > kWatchLogBacklog) {
    log_.pop_front();
  }
}

void WatchServer::set_probes(std::string json) {
  probes_ = std::move(json);
  broadcast("probes", probes_);
}

}  // namespace gamepilot
