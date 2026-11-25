// The board's session against FakeSwitch's board: the handshake in the C++
// app's order, the controller mode check (never a change), the baud rate
// scan, a lost ack and a lost answer (both retransmitted), a board that never
// answers or speaks another protocol, and the Pro Controller commands' bytes
// as the board reads them.

#include "board_session.h"

#include <chrono>
#include <cstdint>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#include "Common/PABotBase2/PABotBase2_MessageProtocol.h"
#include "backend.h"
#include "check.h"
#include "fake_switch.h"

using namespace gamepilot;

namespace {

using Bytes = std::vector<std::uint8_t>;
using pa::ControllerType;

// GBA keys (rpc.cpp, button_mask).
constexpr KeyMask kA = 1u << 0;
constexpr KeyMask kB = 1u << 1;
constexpr KeyMask kSelect = 1u << 2;
constexpr KeyMask kStart = 1u << 3;
constexpr KeyMask kUp = 1u << 6;
constexpr KeyMask kR = 1u << 8;
constexpr KeyMask kL = 1u << 9;
constexpr std::uint32_t kWiredController = 0x1000;
constexpr std::uint32_t kWiredProController = 0x1100;

// Short waits, so a board that never answers fails fast.
BoardTimings quick_timings() {
  BoardTimings timings;
  timings.connect = pa::Milliseconds(300);
  timings.recovery = pa::Milliseconds(100);
  timings.settle = pa::Milliseconds(1);
  return timings;
}

void sleep_ms(int ms) {
  std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

// Waits up to 2 s for the board to have run `count` commands.
std::vector<BoardCommand> wait_for_commands(const FakeSwitch& board,
                                            std::size_t count) {
  for (int i = 0; i < 200 && board.commands().size() < count; i++) {
    sleep_ms(10);
  }
  return board.commands();
}

Bytes message_bytes(const ProButtonsMessage& message) {
  Bytes bytes(sizeof(message));
  std::memcpy(bytes.data(), &message, sizeof(message));
  return bytes;
}

// The board in NS1 Wired Pro Controller mode, as on console B: the session
// asks as the lab app's log of that board shows (protocol, id, firmware, name,
// logging flag, controller list, queue size, mode) and leaves the mode as it
// is.
void check_handshake() {
  const Clock clock;
  FakeSwitch board(clock);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  const BoardInfo info = session.start();
  CHECK(info.baud_rate == 921600);
  CHECK(info.link_protocol == 2026061800);
  CHECK(info.device_protocol == 2026061805);
  CHECK(info.device_id == 0x12);
  CHECK(info.firmware_version == 2026092800);
  CHECK(info.device_name == "PABotBase2-ESP32-S3");
  CHECK(info.controllers.size() == 7);
  CHECK(info.mode == ControllerType::NintendoSwitch_WiredProController);
  CHECK(board.mode() == kWiredProController);

  const std::vector<std::pair<std::uint8_t, std::uint8_t>> expected = {
      {PABB2_MESSAGE_OPCODE_PROTOCOL_VERSION, 0},
      {PABB2_MESSAGE_OPCODE_DEVICE_IDENTIFIER, 1},
      {PABB2_MESSAGE_OPCODE_FIRMWARE_VERSION, 2},
      {PABB2_MESSAGE_OPCODE_DEVICE_NAME, 3},
      {PABB2_MESSAGE_OPCODE_SET_LOGGING_FLAG, 0},
      {PABB2_MESSAGE_OPCODE_CONTROLLER_LIST, 4},
      {PABB2_MESSAGE_OPCODE_CQ_CAPACITY, 5},
      {PABB2_MESSAGE_OPCODE_READ_CONTROLLER_MODE, 6},
  };
  // Status requests follow once the session runs.
  std::vector<std::pair<std::uint8_t, std::uint8_t>> sent;
  for (const BoardMessage& message : board.messages()) {
    if (sent.size() < expected.size()) {
      sent.emplace_back(message.opcode, message.id);
    }
  }
  CHECK(sent == expected);
}

// A board in another mode (here the generic Wired Controller): start() fails
// with a message naming both modes, and never asks for a mode change.
void check_other_mode_fails() {
  const Clock clock;
  FakeBoardProfile wired;
  wired.mode = kWiredController;
  FakeSwitch board(clock, wired);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  std::string error;
  try {
    session.start();
  } catch (const BackendError& e) {
    error = e.what();
  }
  CHECK(error.find("NS1: Wired Controller") != std::string::npos);
  CHECK(error.find("NS1: Wired Pro Controller") != std::string::npos);
  CHECK(board.mode() == kWiredController);
  for (const BoardMessage& message : board.messages()) {
    CHECK(message.opcode != PABB2_MESSAGE_OPCODE_CHANGE_CONTROLLER_MODE);
    CHECK(message.opcode != PABB2_MESSAGE_OPCODE_RESET_TO_CONTROLLER);
  }
}

// The status thread asks once a second; the board says the console sees the
// controller, or not.
void check_status() {
  const Clock clock;
  for (const bool seen : {true, false}) {
    FakeBoardProfile profile;
    profile.console_sees_controller = seen;
    FakeSwitch board(clock, profile);
    BoardLog log(/*quiet=*/true);
    BoardSession session(board, log, quick_timings());
    session.start();
    for (int i = 0; i < 100 && !session.status().answered; i++) {
      sleep_ms(10);
    }
    const BoardStatus status = session.status();
    CHECK(status.answered && status.error.empty());
    CHECK(status.connected == seen);
  }
}

// A board at 115200 answers on the second baud rate tried.
void check_baud_scan() {
  const Clock clock;
  FakeBoardProfile profile;
  profile.baud_rate = 115200;
  FakeSwitch board(clock, profile);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  CHECK(session.start().baud_rate == 115200);
}

// The commands as the board reads them: length 16, opcode 0x97, the queue's
// id, the hold in ms, then report 0x30's buttons (bytes 3-5), both sticks
// centred (00 08 80) and the vibrator byte. The expected bytes come from an
// independent encoder (Python struct over the report layout in dekuNukem's
// bluetooth_hid_notes.md), not from this code.
void check_state_bytes() {
  const Clock clock;
  FakeSwitch board(clock);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  session.start();
  session.send_state(neutral_pro_buttons(), 0);  // release(): a reset
  session.send_state(pro_buttons_for_keys(kA), 100);
  session.send_state(pro_buttons_for_keys(kUp), 500);
  session.send_state(pro_buttons_for_keys(kStart | kB), 80);
  session.send_state(pro_buttons_for_keys(kL | kR | kSelect), 40);
  // A hold past 65535 ms goes in two commands, as issue_report() splits it.
  session.send_state(pro_buttons_for_keys(kA), 70000);
  const std::vector<Bytes> expected = {
      {0x10, 0x00, 0x97, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
      {0x10, 0x00, 0x97, 0x01, 0x64, 0x00, 0x08, 0x00, 0x00, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
      {0x10, 0x00, 0x97, 0x02, 0xf4, 0x01, 0x00, 0x00, 0x02, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
      {0x10, 0x00, 0x97, 0x03, 0x50, 0x00, 0x04, 0x02, 0x00, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
      {0x10, 0x00, 0x97, 0x04, 0x28, 0x00, 0x40, 0x01, 0x40, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
      {0x10, 0x00, 0x97, 0x05, 0xff, 0xff, 0x08, 0x00, 0x00, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
      {0x10, 0x00, 0x97, 0x06, 0x71, 0x11, 0x08, 0x00, 0x00, 0x00, 0x08,
       0x80, 0x00, 0x08, 0x80, 0x00},
  };
  const std::vector<BoardCommand> commands =
      wait_for_commands(board, expected.size());
  CHECK(commands.size() == expected.size());
  for (std::size_t i = 0; i < commands.size() && i < expected.size(); i++) {
    CHECK(message_bytes(commands[i].message) == expected[i]);
  }
}

// The board's ack of a command is lost: the session sends the command again,
// flagged as a retransmit, once the next status answer wakes the link's
// retransmit thread (within the status period plus three 80 ms rounds), and
// the board runs it once. Then the board's report that a command finished is
// lost too, and the board sends it again; the queue keeps moving.
void check_lost_ack_retransmits() {
  const Clock clock;
  FakeSwitch board(clock);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  session.start();
  CHECK(board.retransmits_received() == 0);
  board.drop_next_sends(1);
  session.send_state(pro_buttons_for_keys(kA), 10);
  for (int i = 0; i < 300 && board.retransmits_received() == 0; i++) {
    sleep_ms(10);
  }
  CHECK(board.retransmits_received() >= 1);
  CHECK(wait_for_commands(board, 1).size() == 1);

  // Lose the next ack and the finished report behind it.
  board.drop_next_sends(2);
  for (int i = 0; i < 5; i++) {
    session.send_state(pro_buttons_for_keys(kA), 10);
  }
  const std::vector<BoardCommand> commands = wait_for_commands(board, 6);
  CHECK(commands.size() == 6);
  for (std::size_t i = 0; i < commands.size(); i++) {
    CHECK(commands[i].id == i);
  }
}

// The handshake's answers can be lost too. A lost reset ack: the session
// resets again. A lost version answer: nothing wakes the link's retransmit
// thread, so the request times out and the session connects again.
void check_lost_handshake_answers() {
  const Clock clock;
  BoardLog log(/*quiet=*/true);
  {
    FakeSwitch board(clock);
    BoardSession session(board, log, quick_timings());
    board.drop_next_sends(1);
    CHECK(session.start().link_protocol == 2026061800);
  }
  {
    FakeSwitch board(clock);
    BoardSession session(board, log, quick_timings());
    board.drop_sends_after(1, 1);  // the reset's ack goes, the version's not
    CHECK(session.start().link_protocol == 2026061800);
  }
}

void check_errors() {
  const Clock clock;
  BoardLog log(/*quiet=*/true);
  {
    FakeBoardProfile silent;
    silent.baud_rate = 9600;
    FakeSwitch board(clock, silent);
    BoardSession session(board, log, quick_timings());
    bool threw = false;
    try {
      session.start();
    } catch (const BackendError& error) {
      threw = std::string(error.what()).find("no answer") != std::string::npos;
    }
    CHECK(threw);
  }
  {
    FakeBoardProfile old_board;
    old_board.link_protocol = 2025010100;
    FakeSwitch board(clock, old_board);
    BoardSession session(board, log, quick_timings());
    bool threw = false;
    try {
      session.start();
    } catch (const BackendError& error) {
      threw = std::string(error.what()).find("incompatible") !=
              std::string::npos;
    }
    CHECK(threw);
  }
}

}  // namespace

int main() {
  check_handshake();
  check_other_mode_fails();
  check_status();
  check_baud_scan();
  check_state_bytes();
  check_lost_ack_retransmits();
  check_lost_handshake_answers();
  check_errors();
  return TEST_RESULT();
}
