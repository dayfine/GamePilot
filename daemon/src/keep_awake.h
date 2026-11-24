// Keeps an idle console awake: after `idle_ms` with no input, the daemon
// presses a harmless key (B by default) as a batch of its own. It never
// presses while a client's batch is queued or running, while a client holds
// the input lease (input_lease.h), nor within `idle_ms` of a client's submit,
// so it cannot land inside a program's or a person's input. It
// replaces a second client that pressed B (gp_keepawake.py), which the
// daemon's one-client rule locked out.
//
// The rule is here, the press is the server's: it asks `due` each loop pass
// and, when it says yes, submits the press and calls `pressed`.

#pragma once

#include <string>
#include <string_view>
#include <vector>

#include "backend.h"
#include "schedule.h"

namespace gamepilot {

struct KeepAwakeOptions {
  double idle_ms = 0;  // 0 = off
  std::string key = "B";
};

// The keep-awake press's batch id: its batch_done is not sent to a client.
constexpr std::string_view kKeepAwakeBatch = "daemon.keepawake";

// How long the key is held, then released before anything else runs.
constexpr double kKeepAwakeHoldMs = 80;
constexpr double kKeepAwakeCooldownMs = 200;

class KeepAwake {
 public:
  // `now_ms` counts as the last input: a daemon that just started waits a
  // whole `idle_ms` first.
  KeepAwake(KeepAwakeOptions options, double now_ms);

  bool on() const { return options_.idle_ms > 0; }
  const std::string& key() const { return options_.key; }
  double idle_ms(double now_ms) const { return now_ms - last_input_ms_; }

  // A client submitted (or cancelled), or a batch is still queued or running.
  void input(double now_ms);

  // Whether to press now: on, no batch queued or running, no lease held, and
  // `idle_ms` since the last input or press.
  bool due(double now_ms, bool batch_pending, bool lease_held) const;

  // The press was submitted: the next one is `idle_ms` from now.
  void pressed(double now_ms) { last_input_ms_ = now_ms; }

  // The press as a batch's commands.
  std::vector<InputCommand> press() const;

 private:
  KeepAwakeOptions options_;
  double last_input_ms_ = 0;
};

}  // namespace gamepilot
