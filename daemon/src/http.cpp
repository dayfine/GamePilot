#include "http.h"

#include <algorithm>
#include <stdexcept>

namespace gamepilot {

namespace {

constexpr std::string_view kPartBoundary = "gamepilot-frame";

std::string_view reason_phrase(int status) {
  switch (status) {
    case 200:
      return "OK";
    case 302:
      return "Found";
    case 403:
      return "Forbidden";
    case 404:
      return "Not Found";
    case 405:
      return "Method Not Allowed";
    case 503:
      return "Service Unavailable";
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
  const std::size_t mark = target.find('?');
  const std::size_t line_end = head.find("\r\n");
  return HttpRequest{
      line.substr(0, first), target.substr(0, mark),
      mark == std::string::npos ? std::string() : target.substr(mark + 1),
      line_end == std::string::npos ? std::string()
                                    : head.substr(line_end + 2)};
}

std::string header_value(std::string_view headers, std::string_view name) {
  const auto lower = [](char c) {
    return c >= 'A' && c <= 'Z' ? static_cast<char>(c - 'A' + 'a') : c;
  };
  while (!headers.empty()) {
    const std::size_t end = headers.find("\r\n");
    const std::string_view line = headers.substr(0, end);
    const std::size_t colon = line.find(':');
    if (colon == name.size() &&
        std::equal(name.begin(), name.end(), line.begin(),
                   [&](char a, char b) { return lower(a) == lower(b); })) {
      std::string_view value = line.substr(colon + 1);
      while (!value.empty() && (value.front() == ' ' || value.front() == '\t')) {
        value.remove_prefix(1);
      }
      while (!value.empty() && (value.back() == ' ' || value.back() == '\t')) {
        value.remove_suffix(1);
      }
      return std::string(value);
    }
    if (end == std::string_view::npos) {
      break;
    }
    headers.remove_prefix(end + 2);
  }
  return {};
}

std::string http_response(int status, std::string_view content_type,
                          std::string_view body,
                          std::string_view extra_headers) {
  std::string out = "HTTP/1.1 " + std::to_string(status) + " ";
  out += reason_phrase(status);
  out += "\r\nContent-Type: ";
  out += content_type;
  out += "\r\nContent-Length: " + std::to_string(body.size());
  out += "\r\nCache-Control: no-store\r\nConnection: close\r\n";
  out += extra_headers;
  out += "\r\n";
  out += body;
  return out;
}

std::string query_value(std::string_view query, std::string_view name) {
  while (!query.empty()) {
    const std::size_t amp = query.find('&');
    const std::string_view pair = query.substr(0, amp);
    const std::size_t eq = pair.find('=');
    if (eq != std::string_view::npos && pair.substr(0, eq) == name) {
      return std::string(pair.substr(eq + 1));
    }
    if (amp == std::string_view::npos) {
      break;
    }
    query.remove_prefix(amp + 1);
  }
  return {};
}

std::string event_stream_head() {
  return "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n"
         "Cache-Control: no-store\r\nConnection: keep-alive\r\n\r\n";
}

std::string multipart_stream_head() {
  std::string head =
      "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; "
      "boundary=";
  head += kPartBoundary;
  head += "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n";
  return head;
}

std::string multipart_part(std::string_view content_type,
                           std::string_view body) {
  std::string part = "--";
  part += kPartBoundary;
  part += "\r\nContent-Type: ";
  part += content_type;
  part += "\r\nContent-Length: " + std::to_string(body.size()) + "\r\n\r\n";
  part += body;
  part += "\r\n";
  return part;
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
