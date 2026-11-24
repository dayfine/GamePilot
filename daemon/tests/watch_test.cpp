// The watch page's HTTP pieces: request heads, responses, event framing, and
// the server end to end over loopback (page, frame, event stream with its
// snapshot, Stop, errors).

#include <string>
#include <vector>

#include "check.h"
#include "http.h"
#include "net.h"
#include "watch_server.h"

using namespace gamepilot;

namespace {

void check_request_heads() {
  std::string buffer = "GET /frame.jpg?t=12 HTTP/1.1\r\nHost: x\r\n";
  CHECK(!take_request_head(buffer));  // no blank line yet
  buffer += "\r\nPOST /stop HTTP/1.1\r\n\r\n";
  const auto first = take_request_head(buffer);
  CHECK(first && first->method == "GET" && first->path == "/frame.jpg");
  const auto second = take_request_head(buffer);
  CHECK(second && second->method == "POST" && second->path == "/stop");
  CHECK(buffer.empty());

  for (std::string bad :
       {"GET\r\n\r\n", "GET / FTP/1\r\n\r\n", "GET nopath HTTP/1.1\r\n\r\n"}) {
    bool threw = false;
    try {
      take_request_head(bad);
    } catch (const std::invalid_argument&) {
      threw = true;
    }
    CHECK(threw);
  }
  std::string endless(kMaxRequestHead + 1, 'a');
  bool threw = false;
  try {
    take_request_head(endless);
  } catch (const std::invalid_argument&) {
    threw = true;
  }
  CHECK(threw);
}

void check_framing() {
  const std::string ok = http_response(200, "text/plain", "hi");
  CHECK(ok.starts_with("HTTP/1.1 200 OK\r\n"));
  CHECK(ok.find("Content-Length: 2\r\n") != std::string::npos);
  CHECK(ok.find("Connection: close\r\n") != std::string::npos);
  CHECK(ok.ends_with("\r\n\r\nhi"));
  CHECK(http_response(404, "text/plain", "")
            .starts_with("HTTP/1.1 404 Not Found\r\n"));
  CHECK(event_message("log", "{\"line\":\"a\"}") ==
        "event: log\ndata: {\"line\":\"a\"}\n\n");
  // A newline in the data would end the event early: each line is its own
  // data line, which the browser joins back with a newline.
  CHECK(event_message("x", "a\nb") == "event: x\ndata: a\ndata: b\n\n");
  CHECK(event_stream_head().find("text/event-stream") != std::string::npos);
}

// Serves until the client has `want` in what it received (or gives up).
std::string exchange(WatchServer& server, Socket& client,
                     const std::string& want) {
  std::string received;
  for (int round = 0; round < 50 && received.find(want) == std::string::npos;
       round++) {
    server.serve(poll_readable(server.sockets(), 20));
    if (poll_readable({&client}, 20)[0]) {
      const auto data = client.receive_some();
      if (!data) {
        break;
      }
      received += *data;
    }
  }
  return received;
}

std::string request(WatchServer& server, const std::string& head,
                    const std::string& want) {
  Socket client = connect_local(server.port());
  client.send_all(head);
  return exchange(server, client, want);
}

void check_server() {
  int stops = 0;
  WatchServer server(WatchOptions{"127.0.0.1", 0},
                     WatchHooks{[] { return WatchFrame{"image/png", "PNGBYTES"}; },
                                [&stops] {
                                  stops++;
                                  return true;
                                }});
  CHECK(server.port() != 0);
  CHECK(!server.has_viewers());

  const std::string page = request(server, "GET / HTTP/1.1\r\n\r\n", "</html>");
  CHECK(page.starts_with("HTTP/1.1 200 OK"));
  CHECK(page.find("text/html") != std::string::npos);
  CHECK(page.find("GamePilot") != std::string::npos);

  const std::string frame =
      request(server, "GET /frame?t=1 HTTP/1.1\r\n\r\n", "PNGBYTES");
  CHECK(frame.find("image/png") != std::string::npos);
  CHECK(frame.ends_with("PNGBYTES"));

  CHECK(request(server, "GET /nothing HTTP/1.1\r\n\r\n", "\r\n\r\n")
            .starts_with("HTTP/1.1 404"));
  CHECK(request(server, "GET /stop HTTP/1.1\r\n\r\n", "\r\n\r\n")
            .starts_with("HTTP/1.1 405"));
  CHECK(stops == 0);
  CHECK(request(server, "POST /stop HTTP/1.1\r\n\r\n", "}")
            .ends_with("{\"stopped\":true}"));
  CHECK(stops == 1);

  // Kept before a viewer came: it gets the latest of each, then live events.
  server.set_info("{\"i\":1}");
  server.set_plan("{\"p\":1}");
  server.set_plan("{\"p\":2}");
  server.add_log("{\"line\":\"one\"}");
  server.broadcast("status", "{\"s\":0}");  // not kept
  Socket viewer = connect_local(server.port());
  viewer.send_all("GET /events HTTP/1.1\r\n\r\n");
  const std::string snapshot = exchange(server, viewer, "\"one\"");
  CHECK(snapshot.starts_with("HTTP/1.1 200 OK"));
  CHECK(snapshot.find("event: info\ndata: {\"i\":1}") != std::string::npos);
  CHECK(snapshot.find("{\"p\":1}") == std::string::npos);
  CHECK(snapshot.find("event: plan\ndata: {\"p\":2}") != std::string::npos);
  CHECK(snapshot.find("\"s\":0") == std::string::npos);
  CHECK(server.has_viewers());
  CHECK(server.take_joined());
  CHECK(!server.take_joined());

  server.add_log("{\"line\":\"two\"}");
  server.broadcast("status", "{\"s\":1}");
  const std::string live = exchange(server, viewer, "\"s\":1");
  CHECK(live.find("event: log\ndata: {\"line\":\"two\"}") != std::string::npos);
  CHECK(live.find("event: status\ndata: {\"s\":1}") != std::string::npos);

  viewer.close();
  for (int round = 0; round < 20 && server.has_viewers(); round++) {
    server.serve(poll_readable(server.sockets(), 20));
  }
  CHECK(!server.has_viewers());
}

}  // namespace

int main() {
  init_sockets();
  check_request_heads();
  check_framing();
  check_server();
  return TEST_RESULT();
}
