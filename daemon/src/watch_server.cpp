#include "watch_server.h"

#include <algorithm>
#include <random>
#include <stdexcept>
#include <utility>

#include "watch_assets.h"

namespace gamepilot {

namespace {

constexpr std::size_t kMaxTokenLength = 64;
constexpr std::string_view kTokenSlot = "name=\"gamepilot-token\" content=\"\"";
constexpr std::string_view kNoStop = "{\"stopped\":false,\"error\":\"token\"}";

}  // namespace

std::string page_with_token(std::string_view token) {
  std::string page(watch_page());
  const std::size_t slot = page.find(kTokenSlot);
  if (slot != std::string::npos && !token.empty()) {
    page.insert(slot + kTokenSlot.size() - 1, token);
  }
  return page;
}

std::string page_token(std::string_view page) {
  constexpr std::string_view kOpen = "name=\"gamepilot-token\" content=\"";
  const std::size_t at = page.find(kOpen);
  if (at == std::string_view::npos) {
    return {};
  }
  const std::size_t start = at + kOpen.size();
  const std::size_t end = page.find('"', start);
  if (end == std::string_view::npos) {
    return {};
  }
  const std::string token(page.substr(start, end - start));
  return valid_watch_token(token) ? token : std::string();
}

std::string new_watch_token() {
  std::random_device random;
  std::uniform_int_distribution<int> digit(0, 15);
  constexpr std::string_view kHex = "0123456789abcdef";
  constexpr int kDigits = 32;
  std::string token;
  for (int i = 0; i < kDigits; i++) {
    token += kHex[static_cast<std::size_t>(digit(random))];
  }
  return token;
}

bool valid_watch_token(std::string_view token) {
  return !token.empty() && token.size() <= kMaxTokenLength &&
         std::all_of(token.begin(), token.end(), [](char c) {
           return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
                  (c >= 'A' && c <= 'Z') || c == '-' || c == '_';
         });
}

WatchServer::WatchServer(const WatchOptions& options, WatchHooks hooks,
                         StreamOptions stream)
    : listener_(listen_tcp(options.listen, options.port)),
      token_(options.token.empty() ? new_watch_token() : options.token),
      hooks_(std::move(hooks)),
      stream_options_(stream),
      stream_(stream) {
  if (!valid_watch_token(token_)) {
    throw std::runtime_error("bad watch token");
  }
}

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
    const bool local = peer_is_loopback(socket);
    connections_.push_back(Connection{std::move(socket), {}, false, local});
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
  if (get && request.path == "/stream") {
    start_frame_stream(connection, request);
    return;
  }
  // The page's scripts and styles, beside it (watch_assets.h).
  const auto asset = watch_asset(std::string_view(request.path).substr(1));
  if (get && request.path == "/") {
    const bool local = connection.local &&
                       header_value(request.headers, kViewerHeader) !=
                           kRemoteViewer;
    send(connection, http_response(200, "text/html; charset=utf-8",
                                   page_with_token(local ? token_ : "")));
  } else if (get && asset) {
    send(connection, http_response(200, asset->type, asset->bytes,
                                   "Cache-Control: no-cache\r\n"));
  } else if (get && request.path == "/frame") {
    const WatchFrame frame = hooks_.frame();
    send(connection, http_response(200, frame.type, frame.bytes));
  } else if (get && request.path == "/summary.json") {
    const std::string body =
        "{\"run\":" + (run_.empty() ? std::string("null") : run_) +
        ",\"plan\":" + (plan_.empty() ? std::string("null") : plan_) +
        (source_.empty() ? std::string() : ",\"source\":" + source_) + "}";
    send(connection, http_response(200, "application/json", body,
                                   "Access-Control-Allow-Origin: *\r\n"));
  } else if (request.method == "POST" && request.path == "/stop") {
    stop(connection, request);
  } else if (request.path == "/stop" || request.path == "/" ||
             request.path == "/frame" || request.path == "/events" ||
             request.path == "/stream" ||
             request.path == "/summary.json" || asset) {
    send(connection, http_response(405, "text/plain", "method not allowed\n"));
  } else {
    send(connection, http_response(404, "text/plain", "not found\n"));
  }
  connection.socket.close();
}

// Only with the run's token: the page has it when it was served to this
// machine or its URL carried it.
void WatchServer::stop(Connection& connection, const HttpRequest& request) {
  if (query_value(request.query, "token") != token_) {
    send(connection, http_response(403, "application/json", kNoStop));
    return;
  }
  const bool stopped = hooks_.stop();
  send(connection,
       http_response(200, "application/json",
                     stopped ? "{\"stopped\":true}" : "{\"stopped\":false}"));
}

void WatchServer::start_stream(Connection& connection) {
  connection.streaming = true;
  joined_ = true;
  std::string snapshot = event_stream_head();
  if (!info_.empty()) {
    snapshot += event_message("info", info_);
  }
  if (!run_.empty()) {
    snapshot += event_message("run", run_);
  }
  if (!plan_.empty()) {
    snapshot += event_message("plan", plan_);
  }
  if (!source_.empty()) {
    snapshot += event_message("source", source_);
  }
  for (const std::string& line : log_) {
    snapshot += event_message("log", line);
  }
  if (!probes_.empty()) {
    snapshot += event_message("probes", probes_);
  }
  send(connection, snapshot);
}

// The stream's head here, then the socket goes to the stream's worker, which
// sends the frames.
void WatchServer::start_frame_stream(Connection& connection,
                                     const HttpRequest& request) {
  if (stream_.viewers() >= kStreamMaxViewers) {
    send(connection, http_response(503, "text/plain", "too many viewers\n"));
    connection.socket.close();
    return;
  }
  send(connection, multipart_stream_head());
  if (connection.socket.valid()) {
    stream_.add_viewer(
        std::move(connection.socket),
        stream_width(query_value(request.query, "w"), stream_options_.width));
  }
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

void WatchServer::set_run(std::string json) {
  run_ = std::move(json);
  broadcast("run", run_);
}

void WatchServer::set_source(std::string json) {
  source_ = std::move(json);
  broadcast("source", source_);
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
