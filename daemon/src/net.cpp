#include "net.h"

#include <cerrno>
#include <stdexcept>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

namespace gamepilot {

namespace {

#ifdef _WIN32
using NativeSocket = SOCKET;
constexpr NativeSocket kNativeInvalid = INVALID_SOCKET;
#else
using NativeSocket = int;
constexpr NativeSocket kNativeInvalid = -1;
#endif

NativeSocket native(std::intptr_t handle) {
  return static_cast<NativeSocket>(handle);
}

std::intptr_t wrap(NativeSocket socket) {
  if (socket == kNativeInvalid) {
    return Socket::kInvalid;
  }
  return static_cast<std::intptr_t>(socket);
}

sockaddr_in loopback(std::uint16_t port) {
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(port);
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  return address;
}

void set_no_delay(NativeSocket socket) {
  int one = 1;
  setsockopt(socket, IPPROTO_TCP, TCP_NODELAY,
             reinterpret_cast<const char*>(&one), sizeof(one));
}

}  // namespace

Socket::~Socket() { close(); }

Socket::Socket(Socket&& other) noexcept : handle_(other.handle_) {
  other.handle_ = kInvalid;
}

Socket& Socket::operator=(Socket&& other) noexcept {
  if (this != &other) {
    close();
    handle_ = other.handle_;
    other.handle_ = kInvalid;
  }
  return *this;
}

void Socket::close() {
  if (handle_ == kInvalid) {
    return;
  }
#ifdef _WIN32
  closesocket(native(handle_));
#else
  ::close(native(handle_));
#endif
  handle_ = kInvalid;
}

bool Socket::send_all(const std::string& data) {
  std::size_t sent = 0;
  while (sent < data.size()) {
    const std::size_t chunk = data.size() - sent;
#ifdef _WIN32
    const int n =
        ::send(native(handle_), data.data() + sent,
               static_cast<int>(chunk > 1u << 30 ? 1u << 30 : chunk), 0);
#elif defined(MSG_NOSIGNAL)
    const auto n =
        ::send(native(handle_), data.data() + sent, chunk, MSG_NOSIGNAL);
#else
    const auto n = ::send(native(handle_), data.data() + sent, chunk, 0);
#endif
    if (n <= 0) {
      return false;
    }
    sent += static_cast<std::size_t>(n);
  }
  return true;
}

std::optional<std::size_t> Socket::send_some(const char* data,
                                             std::size_t size) {
#ifdef _WIN32
  const int n = ::send(native(handle_), data,
                       static_cast<int>(size > 1u << 30 ? 1u << 30 : size), 0);
  const bool would_block = n < 0 && WSAGetLastError() == WSAEWOULDBLOCK;
#elif defined(MSG_NOSIGNAL)
  const auto n = ::send(native(handle_), data, size, MSG_NOSIGNAL);
  const bool would_block = n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK);
#else
  const auto n = ::send(native(handle_), data, size, 0);
  const bool would_block = n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK);
#endif
  if (would_block) {
    return 0;
  }
  if (n <= 0) {
    return std::nullopt;
  }
  return static_cast<std::size_t>(n);
}

std::optional<std::string> Socket::receive_some() {
  char buffer[4096];
#ifdef _WIN32
  const int n =
      ::recv(native(handle_), buffer, static_cast<int>(sizeof(buffer)), 0);
#else
  const auto n = ::recv(native(handle_), buffer, sizeof(buffer), 0);
#endif
  if (n <= 0) {
    return std::nullopt;
  }
  return std::string(buffer, static_cast<std::size_t>(n));
}

void init_sockets() {
#ifdef _WIN32
  static const bool started = [] {
    WSADATA data;
    return WSAStartup(MAKEWORD(2, 2), &data) == 0;
  }();
  if (!started) {
    throw std::runtime_error("WSAStartup failed");
  }
#endif
}

Socket listen_tcp(const std::string& address, std::uint16_t port) {
  sockaddr_in bound{};
  bound.sin_family = AF_INET;
  bound.sin_port = htons(port);
  if (inet_pton(AF_INET, address.c_str(), &bound.sin_addr) != 1) {
    throw std::runtime_error("not an IPv4 address: " + address);
  }
  const NativeSocket socket = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (socket == kNativeInvalid) {
    throw std::runtime_error("socket() failed");
  }
  Socket result(wrap(socket));
  int one = 1;
  setsockopt(socket, SOL_SOCKET, SO_REUSEADDR,
             reinterpret_cast<const char*>(&one), sizeof(one));
  const std::string where = address + ":" + std::to_string(port);
  if (::bind(socket, reinterpret_cast<const sockaddr*>(&bound),
             sizeof(bound)) != 0) {
    throw std::runtime_error("cannot bind " + where);
  }
  if (::listen(socket, 8) != 0) {
    throw std::runtime_error("cannot listen on " + where);
  }
  return result;
}

Socket listen_local(std::uint16_t port) {
  return listen_tcp("127.0.0.1", port);
}

std::uint16_t local_port(const Socket& socket) {
  sockaddr_in address{};
#ifdef _WIN32
  int size = sizeof(address);
#else
  socklen_t size = sizeof(address);
#endif
  if (getsockname(native(socket.handle()),
                  reinterpret_cast<sockaddr*>(&address), &size) != 0) {
    return 0;
  }
  return ntohs(address.sin_port);
}

bool peer_is_loopback(const Socket& socket) {
  sockaddr_in address{};
#ifdef _WIN32
  int size = sizeof(address);
#else
  socklen_t size = sizeof(address);
#endif
  if (getpeername(native(socket.handle()),
                  reinterpret_cast<sockaddr*>(&address), &size) != 0 ||
      address.sin_family != AF_INET) {
    return false;
  }
  constexpr std::uint32_t kLoopbackNet = 0x7f000000;  // 127.0.0.0/8
  constexpr std::uint32_t kNetMask = 0xff000000;
  return (ntohl(address.sin_addr.s_addr) & kNetMask) == kLoopbackNet;
}

void set_send_timeout(const Socket& socket, int ms) {
#ifdef _WIN32
  const DWORD timeout = static_cast<DWORD>(ms);
#else
  timeval timeout{};
  timeout.tv_sec = ms / 1000;
  timeout.tv_usec = (ms % 1000) * 1000;
#endif
  setsockopt(native(socket.handle()), SOL_SOCKET, SO_SNDTIMEO,
             reinterpret_cast<const char*>(&timeout), sizeof(timeout));
}

void set_nonblocking(const Socket& socket) {
#ifdef _WIN32
  u_long on = 1;
  ioctlsocket(native(socket.handle()), FIONBIO, &on);
#else
  const int flags = fcntl(native(socket.handle()), F_GETFL, 0);
  fcntl(native(socket.handle()), F_SETFL, flags | O_NONBLOCK);
#endif
}

Socket accept_client(const Socket& listener) {
  const NativeSocket socket =
      ::accept(native(listener.handle()), nullptr, nullptr);
  if (socket == kNativeInvalid) {
    return Socket();
  }
  set_no_delay(socket);
#ifdef SO_NOSIGPIPE
  int one = 1;
  setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#endif
  return Socket(wrap(socket));
}

Socket connect_local(std::uint16_t port) {
  const NativeSocket socket = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (socket == kNativeInvalid) {
    throw std::runtime_error("socket() failed");
  }
  Socket result(wrap(socket));
  const sockaddr_in address = loopback(port);
  if (::connect(socket, reinterpret_cast<const sockaddr*>(&address),
                sizeof(address)) != 0) {
    throw std::runtime_error("cannot connect to 127.0.0.1:" +
                             std::to_string(port));
  }
  set_no_delay(socket);
#ifdef SO_NOSIGPIPE
  int one = 1;
  setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#endif
  return result;
}

std::vector<bool> poll_readable(const std::vector<const Socket*>& sockets,
                                int timeout_ms) {
#ifdef _WIN32
  std::vector<WSAPOLLFD> fds;
#else
  std::vector<pollfd> fds;
#endif
  std::vector<std::size_t> index;
  for (std::size_t i = 0; i < sockets.size(); i++) {
    if (sockets[i] != nullptr && sockets[i]->valid()) {
      fds.push_back({});
      fds.back().fd = native(sockets[i]->handle());
      fds.back().events = POLLIN;
      index.push_back(i);
    }
  }
  std::vector<bool> readable(sockets.size(), false);
  if (fds.empty()) {
    return readable;
  }
#ifdef _WIN32
  const int n = WSAPoll(fds.data(), static_cast<ULONG>(fds.size()), timeout_ms);
#else
  const int n = ::poll(fds.data(), static_cast<nfds_t>(fds.size()), timeout_ms);
#endif
  if (n <= 0) {
    return readable;
  }
  for (std::size_t k = 0; k < fds.size(); k++) {
    if ((fds[k].revents & (POLLIN | POLLHUP | POLLERR)) != 0) {
      readable[index[k]] = true;
    }
  }
  return readable;
}

std::optional<std::string> LineBuffer::next_line() {
  const std::size_t newline = buffer_.find('\n');
  if (newline == std::string::npos) {
    return std::nullopt;
  }
  std::string line = buffer_.substr(0, newline);
  buffer_.erase(0, newline + 1);
  if (!line.empty() && line.back() == '\r') {
    line.pop_back();
  }
  return line;
}

}  // namespace gamepilot
