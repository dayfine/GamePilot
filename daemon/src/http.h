// The little HTTP/1.1 the watch page needs: request heads in, whole responses
// and a Server-Sent Events stream out. Every response closes its connection
// except the event stream, so there is no keep-alive or chunking to handle.

#pragma once

#include <cstddef>
#include <optional>
#include <string>
#include <string_view>

namespace gamepilot {

struct HttpRequest {
  std::string method;  // "GET", "POST", ...
  std::string path;    // without the query string
  std::string query;   // after the '?', empty when none
  std::string headers;  // the header lines as they came, CRLF-separated
};

// The value of header `name` (any case) in `headers`, trimmed; empty when it
// is missing.
std::string header_value(std::string_view headers, std::string_view name);

// The header the hub (watch_hub.h) adds to a request it passes on to a run's
// page for a browser on another machine: the hub itself connects from
// loopback, so without it the run would take that browser for a local one and
// hand it Stop's token. The hub writes every head it passes on itself, so a
// browser cannot set or drop it.
constexpr std::string_view kViewerHeader = "X-GamePilot-Viewer";
constexpr std::string_view kRemoteViewer = "remote";

// A head longer than this is refused (no page sends one).
constexpr std::size_t kMaxRequestHead = 8192;

// Takes one request head (up to its blank line) off the front of `buffer`;
// nothing while it is incomplete. A body is not read: the page's requests
// have none. Throws std::invalid_argument on a malformed or oversized head.
std::optional<HttpRequest> take_request_head(std::string& buffer);

// A complete response with `body`, closing the connection. `extra_headers`
// are whole header lines, each ending in CRLF.
std::string http_response(int status, std::string_view content_type,
                          std::string_view body,
                          std::string_view extra_headers = {});

// The value of `name` in a query string ("a=1&token=x"), as it is (the
// watch page's values need no decoding); empty when it is missing.
std::string query_value(std::string_view query, std::string_view name);

// The head of a text/event-stream response; events follow it.
std::string event_stream_head();

// The head of a multipart/x-mixed-replace response (an MJPEG stream): each
// part replaces the last in the browser's <img>.
std::string multipart_stream_head();

// One part of that stream: its head, then `body`.
std::string multipart_part(std::string_view content_type,
                           std::string_view body);

// One event: `event: name` and `data` (each of its lines as a `data:` line).
std::string event_message(std::string_view name, std::string_view data);

}  // namespace gamepilot
