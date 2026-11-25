#include "keep_awake.h"

#include <utility>

#include "rpc.h"

namespace gamepilot {

KeepAwake::KeepAwake(KeepAwakeOptions options, double now_ms)
    : options_(std::move(options)), last_input_ms_(now_ms) {}

void KeepAwake::input(double now_ms) {
  if (now_ms > last_input_ms_) {
    last_input_ms_ = now_ms;
  }
}

bool KeepAwake::due(double now_ms, bool batch_pending, bool lease_held) const {
  return on() && !batch_pending && !lease_held &&
         now_ms - last_input_ms_ >= options_.idle_ms;
}

bool keep_awake_key(const std::string& key) {
  return key == kRightStickKey || button_mask(key) != 0;
}

std::vector<InputCommand> KeepAwake::press() const {
  InputCommand command;
  command.hold_ms = kKeepAwakeHoldMs;
  command.cooldown_ms = kKeepAwakeCooldownMs;
  if (options_.key != kRightStickKey) {
    command.buttons = button_mask(options_.key);
    return {command};
  }
  // Up, then down as long: the camera's pitch comes back and its heading
  // never moves, so a walk's camera-relative legs keep their aim.
  InputCommand up = command;
  up.right_stick = StickPosition{0, 1};
  up.cooldown_ms = 0;
  command.right_stick = StickPosition{0, -1};
  return {up, command};
}

}  // namespace gamepilot
