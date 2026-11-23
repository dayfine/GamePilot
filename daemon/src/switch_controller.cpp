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

// The longest hold one command carries.
constexpr std::uint32_t kMaxCommandMs = 65535;

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

Pabb2Controller::Pabb2Controller(pa::UnreliableStreamSender& port,
                                 std::uint32_t session_id)
    // 24: the packet size PABotBase2CC_ReliableStreamConnection.cpp uses.
    : sender_(port, 24, session_id) {}

void Pabb2Controller::reset() {
  std::lock_guard<std::mutex> guard(lock_);
  sender_.send_reset();
}

bool Pabb2Controller::send_state(const WiredState& state,
                                 std::uint32_t milliseconds) {
  std::lock_guard<std::mutex> guard(lock_);
  do {
    const std::uint32_t chunk = std::min(milliseconds, kMaxCommandMs);
    const WiredStateMessage message = wired_state_message(
        state, static_cast<std::uint16_t>(chunk), next_command_id_);
    if (!sender_.send_stream_all_or_nothing(&message, sizeof(message))) {
      return false;
    }
    next_command_id_++;
    milliseconds -= chunk;
  } while (milliseconds > 0);
  return true;
}

void Pabb2Controller::receive(const void* data, size_t bytes) {
  std::lock_guard<std::mutex> guard(lock_);
  parser_.push_bytes(*this, sender_.session_id(),
                     static_cast<const std::uint8_t*>(data), bytes);
}

std::uint8_t Pabb2Controller::unacknowledged() const {
  std::lock_guard<std::mutex> guard(lock_);
  return sender_.slots_used();
}

void Pabb2Controller::on_packet(const pa::PABotBase2::PacketHeader* packet) {
  if (packet->magic_number != PABB2_PacketParser_RESULT_VALID) {
    return;
  }
  switch (packet->opcode) {
    case PABB2_CONNECTION_OPCODE_RET_RESET:
    case PABB2_CONNECTION_OPCODE_RET_STREAM_DATA:
      sender_.remove(packet->seqnum);
      return;
    default:
      return;
  }
}

size_t RecordingSerialPort::unreliable_send(const void* data,
                                            size_t bytes) noexcept {
  const auto* begin = static_cast<const std::uint8_t*>(data);
  std::lock_guard<std::mutex> guard(lock_);
  writes_.push_back(Write{clock_.now_ms(), {begin, begin + bytes}});
  return bytes;
}

std::vector<RecordingSerialPort::Write> RecordingSerialPort::writes() const {
  std::lock_guard<std::mutex> guard(lock_);
  return writes_;
}

}  // namespace gamepilot
