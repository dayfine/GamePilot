#include "switch_controller.h"

#include <array>
#include <utility>

namespace gamepilot {

namespace {

// Report 0x30's button bits as populate_report_buttons() sets them.
// button3: the right side.
constexpr std::uint8_t kProB = 1u << 2;
constexpr std::uint8_t kProA = 1u << 3;
constexpr std::uint8_t kProR = 1u << 6;
// button4: the shared buttons.
constexpr std::uint8_t kProMinus = 1u << 0;
constexpr std::uint8_t kProPlus = 1u << 1;
// button5: the left side, the D-pad as execute_state() splits it.
constexpr std::uint8_t kProDown = 1u << 0;
constexpr std::uint8_t kProUp = 1u << 1;
constexpr std::uint8_t kProRight = 1u << 2;
constexpr std::uint8_t kProLeft = 1u << 3;
constexpr std::uint8_t kProL = 1u << 6;

// A centred stick: 2048 on both 12-bit axes, as encode_joystick() packs it
// and execute_state() initialises it.
constexpr std::array<std::uint8_t, 3> kStickCentre = {0x00, 0x08, 0x80};

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

bool has(KeyMask keys, KeyMask bit) { return (keys & bit) != 0; }

void set_if(std::uint8_t& byte, bool on, std::uint8_t bit) {
  if (on) {
    byte = static_cast<std::uint8_t>(byte | bit);
  }
}

}  // namespace

ProButtons neutral_pro_buttons() {
  ProButtons buttons{};
  for (std::size_t i = 0; i < kStickCentre.size(); i++) {
    buttons.left_joystick[i] = kStickCentre[i];
    buttons.right_joystick[i] = kStickCentre[i];
  }
  return buttons;
}

ProButtons pro_buttons_for_keys(KeyMask keys) {
  ProButtons buttons = neutral_pro_buttons();
  set_if(buttons.button3, has(keys, kGbaA), kProA);
  set_if(buttons.button3, has(keys, kGbaB), kProB);
  set_if(buttons.button3, has(keys, kGbaR), kProR);
  set_if(buttons.button4, has(keys, kGbaStart), kProPlus);
  set_if(buttons.button4, has(keys, kGbaSelect), kProMinus);
  set_if(buttons.button5, has(keys, kGbaL), kProL);
  const int x = (has(keys, kGbaRight) ? 1 : 0) - (has(keys, kGbaLeft) ? 1 : 0);
  const int y = (has(keys, kGbaDown) ? 1 : 0) - (has(keys, kGbaUp) ? 1 : 0);
  set_if(buttons.button5, y > 0, kProDown);
  set_if(buttons.button5, y < 0, kProUp);
  set_if(buttons.button5, x > 0, kProRight);
  set_if(buttons.button5, x < 0, kProLeft);
  return buttons;
}

ProButtonsMessage pro_buttons_message(const ProButtons& buttons,
                                      std::uint16_t milliseconds) {
  ProButtonsMessage message{};
  message.message_bytes = sizeof(message);
  message.opcode = PABB2_MESSAGE_CMD_NS1_OEM_CONTROLLER_BUTTONS;
  message.milliseconds = milliseconds;
  message.buttons = buttons;
  return message;
}

}  // namespace gamepilot
