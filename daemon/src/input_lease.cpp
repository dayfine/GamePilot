#include "input_lease.h"

namespace gamepilot {

std::optional<LeaseHolder> InputLease::acquire(int connection,
                                               const std::string& owner,
                                               const std::string& client,
                                               double ttl_ms, double now_ms) {
  if (holder_ && holder_->connection != connection) {
    return holder_;
  }
  if (!holder_) {
    holder_ = LeaseHolder{connection, owner, client, now_ms, now_ms, ttl_ms};
    return std::nullopt;
  }
  holder_->owner = owner;
  holder_->client = client;
  holder_->ttl_ms = ttl_ms;
  holder_->last_input_ms = now_ms;
  return std::nullopt;
}

std::optional<LeaseHolder> InputLease::input(int connection,
                                             const std::string& client,
                                             double now_ms) {
  if (holder_ && holder_->connection != connection) {
    return holder_;
  }
  if (!holder_) {
    const std::string owner =
        client.empty() ? "connection " + std::to_string(connection) : client;
    holder_ = LeaseHolder{connection, owner,  client,
                          now_ms,     now_ms, kDefaultLeaseTtlMs};
    return std::nullopt;
  }
  holder_->last_input_ms = now_ms;
  return std::nullopt;
}

bool InputLease::release(int connection) {
  if (!held_by(connection)) {
    return false;
  }
  holder_.reset();
  return true;
}

void InputLease::expire(double now_ms, bool busy) {
  if (!holder_) {
    return;
  }
  if (busy) {
    holder_->last_input_ms = now_ms;
    return;
  }
  if (now_ms - holder_->last_input_ms >= holder_->ttl_ms) {
    holder_.reset();
  }
}

}  // namespace gamepilot
