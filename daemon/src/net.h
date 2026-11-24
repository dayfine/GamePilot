// Minimal blocking/non-blocking TCP for the daemon's single-threaded loop:
// the program's port on 127.0.0.1, the watch page's on an address the user
// chose. POSIX sockets on macOS/Linux, Winsock on Windows.

#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace gamepilot {

class Socket {
 public:
  Socket() = default;
  explicit Socket(std::intptr_t handle) : handle_(handle) {}
  ~Socket();
  Socket(Socket&& other) noexcept;
  Socket& operator=(Socket&& other) noexcept;
  Socket(const Socket&) = delete;
  Socket& operator=(const Socket&) = delete;

  bool valid() const { return handle_ != kInvalid; }
  std::intptr_t handle() const { return handle_; }
  void close();

  // Writes all of `data`; returns false if the peer is gone.
  bool send_all(const std::string& data);
  // Writes what the socket takes now of `size` bytes at `data` (on a
  // non-blocking socket: 0 when its buffer is full). Empty optional = the
  // peer is gone.
  std::optional<std::size_t> send_some(const char* data, std::size_t size);
  // Reads what is available (blocks if nothing is). Empty optional = closed or
  // error.
  std::optional<std::string> receive_some();

  static constexpr std::intptr_t kInvalid = -1;

 private:
  std::intptr_t handle_ = kInvalid;
};

// Starts Winsock once on Windows; no-op elsewhere.
void init_sockets();

// Listens on 127.0.0.1:port. Throws std::runtime_error on failure.
Socket listen_local(std::uint16_t port);
// Listens on an IPv4 address ("127.0.0.1", "0.0.0.0", ...) and port (0 = any
// free port). Throws std::runtime_error on failure.
Socket listen_tcp(const std::string& address, std::uint16_t port);
// The port a listening socket is bound to.
std::uint16_t local_port(const Socket& socket);
// Whether a connected socket's peer is on this machine (127.0.0.0/8).
bool peer_is_loopback(const Socket& socket);
// Makes a send on the socket give up after `ms` instead of blocking for as
// long as the peer does not read.
void set_send_timeout(const Socket& socket, int ms);
// Makes sends and receives on the socket return at once instead of waiting.
void set_nonblocking(const Socket& socket);
// Accepts one pending connection (call after poll says the listener is
// readable).
Socket accept_client(const Socket& listener);
// Connects to 127.0.0.1:port. Throws std::runtime_error on failure.
Socket connect_local(std::uint16_t port);

// Waits up to `timeout_ms` (-1 = forever) for any of `sockets` to be readable.
// Returns one flag per socket; an invalid socket is never readable.
std::vector<bool> poll_readable(const std::vector<const Socket*>& sockets,
                                int timeout_ms);

// Splits a byte stream into LF-terminated lines (a CR before the LF is
// dropped).
class LineBuffer {
 public:
  void append(const std::string& data) { buffer_ += data; }
  std::optional<std::string> next_line();
  std::size_t pending_bytes() const { return buffer_.size(); }

 private:
  std::string buffer_;
};

}  // namespace gamepilot
