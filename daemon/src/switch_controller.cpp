#include "switch_controller.h"

#include <algorithm>
#include <array>

namespace gamepilot {

namespace {

// Switch button bits (NintendoSwitch_ControllerButtons.h, Button) and D-pad
// positions (DpadPosition) the GBA keys map to.
constexpr std::uint16_t kSwitchB = 1u << 1;
constexpr std::uint16_t kSwitchA = 1u << 2;
constexpr std::uint16_t kSwitchL = 1u << 4;
constexpr std::uint16_t kSwitchR = 1u << 5;
constexpr std::uint16_t kSwitchMinus = 1u << 8;
constexpr std::uint16_t kSwitchPlus = 1u << 9;
constexpr std::uint8_t kDpadNone = 8;
constexpr std::uint8_t kStickCentre = 128;

// GBA KEYINPUT bits (rpc.cpp, button_mask).
constexpr KeyMask kGbaA = 1u << 0;
constexpr KeyMask kGbaB = 1u << 1;
constexpr KeyMask kGbaSelect = 1u << 2;
constexpr KeyMask kGbaStart = 1u << 3;
constexpr KeyMask kGbaRight = 1u << 4;
constexpr KeyMask kGbaLeft = 1u << 5;
constexpr KeyMask kGbaUp = 1u << 6;
constexpr KeyMask kGbaDown = 1u << 7;
constexpr KeyMask kGbaR = 1u << 8;
constexpr KeyMask kGbaL = 1u << 9;

// The DpadPosition for a direction, x and y each -1, 0 or 1 (y down), as the
// C++'s execute_state() merges it.
std::uint8_t dpad_position(int x, int y) {
  // Rows: y = -1, 0, 1; columns: x = -1, 0, 1.
  static constexpr std::array<std::array<std::uint8_t, 3>, 3> kPositions = {{
      {7, 0, 1},          // up-left, up, up-right
      {6, kDpadNone, 2},  // left, none, right
      {5, 4, 3},          // down-left, down, down-right
  }};
  return kPositions[static_cast<std::size_t>(y + 1)]
                   [static_cast<std::size_t>(x + 1)];
}

bool has(KeyMask keys, KeyMask bit) { return (keys & bit) != 0; }

}  // namespace

WiredState neutral_wired_state() {
  WiredState state{};
  state.dpad_byte = kDpadNone;
  state.left_joystick_x = kStickCentre;
  state.left_joystick_y = kStickCentre;
  state.right_joystick_x = kStickCentre;
  state.right_joystick_y = kStickCentre;
  return state;
}

WiredState wired_state_for_keys(KeyMask keys) {
  std::uint16_t buttons = 0;
  const std::array<std::pair<KeyMask, std::uint16_t>, 6> kMap = {{
      {kGbaA, kSwitchA},
      {kGbaB, kSwitchB},
      {kGbaL, kSwitchL},
      {kGbaR, kSwitchR},
      {kGbaStart, kSwitchPlus},
      {kGbaSelect, kSwitchMinus},
  }};
  for (const auto& [gba, sw] : kMap) {
    if (has(keys, gba)) {
      buttons = static_cast<std::uint16_t>(buttons | sw);
    }
  }
  const int x = (has(keys, kGbaRight) ? 1 : 0) - (has(keys, kGbaLeft) ? 1 : 0);
  const int y = (has(keys, kGbaDown) ? 1 : 0) - (has(keys, kGbaUp) ? 1 : 0);
  WiredState state = neutral_wired_state();
  state.buttons0 = static_cast<std::uint8_t>(buttons);
  state.buttons1 = static_cast<std::uint8_t>(buttons >> 8);
  state.dpad_byte = dpad_position(x, y);
  return state;
}

WiredStateMessage wired_state_message(const WiredState& state,
                                      std::uint16_t milliseconds,
                                      std::uint8_t id) {
  WiredStateMessage message{};
  message.message_bytes = sizeof(message);
  message.opcode = PABB2_MESSAGE_CMD_NS_WIRED_CONTROLLER_STATE;
  message.id = id;
  message.milliseconds = milliseconds;
  message.report = state;
  return message;
}

}  // namespace gamepilot
