#include "http.h"

#include <stdexcept>

namespace gamepilot {

namespace {

std::string_view reason_phrase(int status) {
  switch (status) {
    case 200:
      return "OK";
    case 404:
      return "Not Found";
    case 405:
      return "Method Not Allowed";
    default:
      return "Error";
  }
}

}  // namespace

std::optional<HttpRequest> take_request_head(std::string& buffer) {
  const std::size_t end = buffer.find("\r\n\r\n");
  if (end == std::string::npos) {
    if (buffer.size() > kMaxRequestHead) {
      throw std::invalid_argument("request head too long");
    }
    return std::nullopt;
  }
  const std::string head = buffer.substr(0, end);
  buffer.erase(0, end + 4);
  const std::string line = head.substr(0, head.find("\r\n"));
  const std::size_t first = line.find(' ');
  const std::size_t second =
      first == std::string::npos ? first : line.find(' ', first + 1);
  if (second == std::string::npos || first == 0 ||
      !line.substr(second + 1).starts_with("HTTP/1.")) {
    throw std::invalid_argument("bad request line: " + line);
  }
  std::string target = line.substr(first + 1, second - first - 1);
  if (!target.starts_with('/')) {
    throw std::invalid_argument("bad request target: " + target);
  }
  return HttpRequest{line.substr(0, first), target.substr(0, target.find('?'))};
}

std::string http_response(int status, std::string_view content_type,
                          std::string_view body) {
  std::string out = "HTTP/1.1 " + std::to_string(status) + " ";
  out += reason_phrase(status);
  out += "\r\nContent-Type: ";
  out += content_type;
  out += "\r\nContent-Length: " + std::to_string(body.size());
  out += "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n";
  out += body;
  return out;
}

std::string event_stream_head() {
  return "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n"
         "Cache-Control: no-store\r\nConnection: keep-alive\r\n\r\n";
}

std::string event_message(std::string_view name, std::string_view data) {
  std::string out = "event: ";
  out += name;
  out += "\n";
  std::size_t start = 0;
  while (true) {
    const std::size_t newline = data.find('\n', start);
    out += "data: ";
    out += data.substr(start, newline == std::string_view::npos
                                  ? std::string_view::npos
                                  : newline - start);
    out += "\n";
    if (newline == std::string_view::npos) {
      break;
    }
    start = newline + 1;
  }
  out += "\n";
  return out;
}

}  // namespace gamepilot
