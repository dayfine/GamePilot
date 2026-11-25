#include "switch_controller.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <utility>

namespace gamepilot {

namespace {

// Report 0x30's button bits as populate_report_buttons() sets them.
// button3: the right side.
constexpr std::uint8_t kProY = 1u << 0;
constexpr std::uint8_t kProX = 1u << 1;
constexpr std::uint8_t kProB = 1u << 2;
constexpr std::uint8_t kProA = 1u << 3;
constexpr std::uint8_t kProR = 1u << 6;
constexpr std::uint8_t kProZR = 1u << 7;
// button4: the shared buttons.
constexpr std::uint8_t kProMinus = 1u << 0;
constexpr std::uint8_t kProPlus = 1u << 1;
constexpr std::uint8_t kProLClick = 1u << 3;
constexpr std::uint8_t kProHome = 1u << 4;
// button5: the left side, the D-pad as execute_state() splits it.
constexpr std::uint8_t kProDown = 1u << 0;
constexpr std::uint8_t kProUp = 1u << 1;
constexpr std::uint8_t kProRight = 1u << 2;
constexpr std::uint8_t kProLeft = 1u << 3;
constexpr std::uint8_t kProL = 1u << 6;
constexpr std::uint8_t kProZL = 1u << 7;

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
// The Switch-only buttons above them (kSwitchOnlyKeys).
constexpr KeyMask kHome = 1u << 10;
constexpr KeyMask kX = 1u << 11;
constexpr KeyMask kY = 1u << 12;
constexpr KeyMask kZL = 1u << 13;
constexpr KeyMask kZR = 1u << 14;
constexpr KeyMask kLClick = 1u << 15;

// encode_joystick()'s range for the Pro Controller
// (PABotBase2_ProController's JOYSTICK_MIN_THRESHOLD and _MAX_THRESHOLD): the
// distance from centre, in 12-bit steps, where the console first registers a
// tilt and where it reads full.
constexpr double kStickCentreAxis = 2048;
constexpr double kStickRegisters = 1874;
constexpr double kStickFull = 320;

bool has(KeyMask keys, KeyMask bit) { return (keys & bit) != 0; }

// JoystickTools::linear_float_to_u12().
std::uint16_t linear_float_to_u12(double f) {
  if (f <= 0) {
    f = std::max(f, -1.0);
    return static_cast<std::uint16_t>(f * 2048 + 2048 + 0.5);
  }
  f = std::min(f, 1.0);
  return static_cast<std::uint16_t>(f * 2047 + 2048 + 0.5);
}

// JoystickTools::max_out_magnitude(): onto the edge of the unit square.
void max_out_magnitude(double& x, double& y) {
  if (x * x + y * y == 0) {
    return;
  }
  const double abs_x = std::abs(x);
  const double abs_y = std::abs(y);
  if (abs_x < abs_y) {
    x /= abs_y;
    y = y < 0 ? -1 : 1;
  } else {
    y /= abs_x;
    x = x < 0 ? -1 : 1;
  }
}

// JoystickTools::project_to_range().
double project_to_range(double x, double lo, double hi) {
  if (x <= -1) {
    return -1;
  }
  if (x >= 1) {
    return 1;
  }
  return x * (hi - lo) + lo;
}

// The 12-bit axes encode_joystick() packs, before packing.
StickAxes stick_axes(StickPosition position) {
  double fx = position.x;
  double fy = position.y;
  const double mag_squared = fx * fx + fy * fy;
  fx = std::clamp(fx, -1.0, 1.0);
  fy = std::clamp(fy, -1.0, 1.0);
  if (mag_squared == 0) {
    return StickAxes{2048, 2048};
  }
  if (mag_squared >= 1) {
    max_out_magnitude(fx, fy);
    return StickAxes{linear_float_to_u12(fx), linear_float_to_u12(fy)};
  }
  constexpr double lo = 1 - kStickRegisters / kStickCentreAxis;
  constexpr double hi = 1 - kStickFull / kStickCentreAxis;
  const double true_mag = std::sqrt(mag_squared);
  const double scale = project_to_range(true_mag, lo, hi) / true_mag;
  return StickAxes{linear_float_to_u12(fx * scale),
                   linear_float_to_u12(fy * scale)};
}

void set_stick(std::uint8_t (&bytes)[3], StickPosition position) {
  const std::array<std::uint8_t, 3> packed = pro_stick_bytes(position);
  std::copy(packed.begin(), packed.end(), bytes);
}

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
  set_if(buttons.button3, has(keys, kX), kProX);
  set_if(buttons.button3, has(keys, kY), kProY);
  set_if(buttons.button3, has(keys, kZR), kProZR);
  set_if(buttons.button4, has(keys, kGbaStart), kProPlus);
  set_if(buttons.button4, has(keys, kGbaSelect), kProMinus);
  set_if(buttons.button4, has(keys, kHome), kProHome);
  set_if(buttons.button4, has(keys, kLClick), kProLClick);
  set_if(buttons.button5, has(keys, kGbaL), kProL);
  set_if(buttons.button5, has(keys, kZL), kProZL);
  const int x = (has(keys, kGbaRight) ? 1 : 0) - (has(keys, kGbaLeft) ? 1 : 0);
  const int y = (has(keys, kGbaDown) ? 1 : 0) - (has(keys, kGbaUp) ? 1 : 0);
  set_if(buttons.button5, y > 0, kProDown);
  set_if(buttons.button5, y < 0, kProUp);
  set_if(buttons.button5, x > 0, kProRight);
  set_if(buttons.button5, x < 0, kProLeft);
  return buttons;
}

ProButtons pro_buttons_for_state(KeyMask keys, const Sticks& sticks) {
  ProButtons buttons = pro_buttons_for_keys(keys);
  set_stick(buttons.left_joystick, sticks.left);
  set_stick(buttons.right_joystick, sticks.right);
  return buttons;
}

std::array<std::uint8_t, 3> pro_stick_bytes(StickPosition position) {
  const StickAxes axes = stick_axes(position);
  return {static_cast<std::uint8_t>(axes.x),
          static_cast<std::uint8_t>(axes.x >> 8 | axes.y << 4),
          static_cast<std::uint8_t>(axes.y >> 4)};
}

StickAxes pro_stick_axes(const std::uint8_t (&bytes)[3]) {
  return StickAxes{
      static_cast<std::uint16_t>(bytes[0] | (bytes[1] & 0x0f) << 8),
      static_cast<std::uint16_t>(bytes[1] >> 4 | bytes[2] << 4)};
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
