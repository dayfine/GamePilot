// Minimal blocking/non-blocking TCP on 127.0.0.1 for the daemon's
// single-threaded loop. POSIX sockets on macOS/Linux, Winsock on Windows.

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
