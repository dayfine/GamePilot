// Keeps an idle console awake: after `idle_ms` with no input, the daemon
// presses a harmless key (B by default) as a batch of its own. It never
// presses while a client's batch is queued or running, while a client holds
// the input lease (input_lease.h), nor within `idle_ms` of a client's submit,
// so it cannot land inside a program's or a person's input. It
// replaces a second client that pressed B (gp_keepawake.py), which the
// daemon's old one-client rule locked out.
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

// The key: a button, or kRightStickKey, a nudge of the right stick up then
// down (the Switch only). PLZA's daemons use the stick: a button is not
// harmless in every PLZA state (B backs out of the new game's menus, A
// answers), while the right stick only moves the camera in the field and does
// nothing in a dialogue, a menu or a battle's HUD; and a console left idle
// with no keep-awake dims its screen, which then reads as nothing (console B,
// 2026-11-25, 01.03's run 2). Up and down, not sideways: a sideways nudge
// turned the camera, and PLZA's walk legs are aimed from where it looks
// (02.01's run 1 walked into the alley's crates).
struct KeepAwakeOptions {
  double idle_ms = 0;  // 0 = off
  std::string key = "B";
};

constexpr std::string_view kRightStickKey = "RStick";

// Whether `key` names a keep-awake key: a button, or kRightStickKey.
bool keep_awake_key(const std::string& key);

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
