// When the daemon's keep-awake presses and when it must not: one case per
// rule, each a name, the input (what happened before the check) and the
// expectation.

#include "keep_awake.h"

#include <cstdio>
#include <optional>
#include <string>
#include <vector>

#include "check.h"
#include "rpc.h"

using namespace gamepilot;

namespace {

constexpr double kIdleMs = 180000;

struct Input {
  double idle_ms = kIdleMs;  // the option; 0 = off
  // Client submits (or batches still running) seen by the loop, in ms since
  // the daemon started.
  std::vector<double> inputs;
  std::optional<double> last_press_ms;  // the keep-awake's own last press
  bool batch_pending = false;           // when it asks
  bool lease_held = false;              // a client holds the input lease
  double now_ms = 0;
};

struct Expectation {
  bool press = false;
};

struct Case {
  std::string name;
  Input input;
  Expectation expect;
};

const std::vector<Case> kCases = {
    {"off never presses",
     {.idle_ms = 0, .now_ms = 10 * kIdleMs},
     {.press = false}},
    {"a daemon that just started waits a whole idle time",
     {.now_ms = kIdleMs - 1},
     {.press = false}},
    {"idle for the whole time since start: presses",
     {.now_ms = kIdleMs},
     {.press = true}},
    {"a client batch pending or running: never",
     {.batch_pending = true, .now_ms = 10 * kIdleMs},
     {.press = false}},
    {"a client holds the input lease: never",
     {.lease_held = true, .now_ms = 10 * kIdleMs},
     {.press = false}},
    {"a client submitted within the window: waits",
     {.inputs = {100000}, .now_ms = 100000 + kIdleMs - 1},
     {.press = false}},
    {"the window since the client's last submit has passed: presses",
     {.inputs = {1000, 100000}, .now_ms = 100000 + kIdleMs},
     {.press = true}},
    {"the batch ran until late: the window counts from its end",
     {.inputs = {1000, 50000, 90000}, .now_ms = 90000 + kIdleMs - 1},
     {.press = false}},
    {"its own press restarts the window",
     {.last_press_ms = kIdleMs, .now_ms = 2 * kIdleMs - 1},
     {.press = false}},
    {"the next press one window after the last",
     {.last_press_ms = kIdleMs, .now_ms = 2 * kIdleMs},
     {.press = true}},
    {"an input older than the last press does not move the window back",
     {.inputs = {1000}, .last_press_ms = kIdleMs, .now_ms = 2 * kIdleMs},
     {.press = true}},
};

void check_cases() {
  for (const Case& c : kCases) {
    KeepAwake keep(KeepAwakeOptions{c.input.idle_ms, "B"}, 0);
    if (c.input.last_press_ms) {
      keep.pressed(*c.input.last_press_ms);
    }
    for (const double t : c.input.inputs) {
      keep.input(t);
    }
    const bool press = keep.due(c.input.now_ms, c.input.batch_pending,
                                c.input.lease_held);
    if (press != c.expect.press) {
      std::fprintf(stderr, "case \"%s\": press %d, expected %d\n",
                   c.name.c_str(), press, c.expect.press);
    }
    CHECK(press == c.expect.press);
  }
}

void check_press() {
  const KeepAwake keep(KeepAwakeOptions{kIdleMs, "B"}, 0);
  const std::vector<InputCommand> press = keep.press();
  CHECK(press.size() == 1 && press[0].buttons == button_mask("B") &&
        press[0].hold_ms == kKeepAwakeHoldMs &&
        press[0].cooldown_ms == kKeepAwakeCooldownMs && !press[0].is_wait);
  // RStick: the right stick tilted, no button.
  const KeepAwake nudge(KeepAwakeOptions{kIdleMs, "RStick"}, 0);
  const std::vector<InputCommand> tilt = nudge.press();
  CHECK(tilt.size() == 1 && tilt[0].buttons == 0 && tilt[0].right_stick &&
        tilt[0].right_stick->x == 1 && !tilt[0].left_stick);
  CHECK(keep_awake_key("RStick") && keep_awake_key("B") &&
        !keep_awake_key("Q"));
}

}  // namespace

int main() {
  check_cases();
  check_press();
  return TEST_RESULT();
}
