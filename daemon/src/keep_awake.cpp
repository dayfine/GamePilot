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
  if (options_.key == kRightStickKey) {
    command.right_stick = StickPosition{1, 0};
  } else {
    command.buttons = button_mask(options_.key);
  }
  command.hold_ms = kKeepAwakeHoldMs;
  command.cooldown_ms = kKeepAwakeCooldownMs;
  return {command};
}

}  // namespace gamepilot
