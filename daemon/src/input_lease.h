// Who may send input: one connection at a time holds the input lease, and only
// it may submit, cancel or load a state. Reads (status, subscribe, frames,
// templates, saves) need no lease, so any number of clients may watch while a
// program or a person drives.
//
// A connection takes the lease with an explicit `lease.acquire {owner,
// ttl_ms}` or implicitly with its first input (the owner is then its hello
// name), so a program that never heard of the lease keeps working. The lease
// ends when its connection disconnects, sends `lease.release`, or sends no
// input for `ttl_ms`; while its batches are queued or running it counts as
// input, and every input renews it. Anyone else's input is refused with the
// holder's owner and how long it has held it.
//
// The rule is here; the server asks it before each input and each loop pass.

#pragma once

#include <optional>
#include <string>

namespace gamepilot {

struct LeaseHolder {
  int connection = 0;  // the server's number for the holding connection
  std::string owner;   // the label it gave, or its hello name
  std::string client;  // its hello name; empty before hello
  double since_ms = 0;
  double last_input_ms = 0;
  double ttl_ms = 0;
};

// The ttl of a lease taken without `lease.acquire` or without `ttl_ms`.
constexpr double kDefaultLeaseTtlMs = 60000;

class InputLease {
 public:
  // Takes the lease for `connection`, or renews it (new owner and ttl, same
  // since) when it holds it already. Returns the holder that refuses it.
  std::optional<LeaseHolder> acquire(int connection, const std::string& owner,
                                     const std::string& client, double ttl_ms,
                                     double now_ms);

  // Input from `connection`: takes the free lease (owner: `client`, or
  // "connection N" before hello) or renews its own. Returns the holder that
  // refuses it.
  std::optional<LeaseHolder> input(int connection, const std::string& client,
                                   double now_ms);

  // Ends `connection`'s lease; false if it held none.
  bool release(int connection);

  // Ends the lease once `ttl_ms` passed since its last input; `busy` (its
  // batches are queued or running) counts as input now.
  void expire(double now_ms, bool busy);

  const std::optional<LeaseHolder>& holder() const { return holder_; }
  bool held_by(int connection) const {
    return holder_ && holder_->connection == connection;
  }

 private:
  std::optional<LeaseHolder> holder_;
};

}  // namespace gamepilot
