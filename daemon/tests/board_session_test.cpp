// The board's session against FakeSwitch's board: the handshake in the C++
// app's order, the controller mode change and its restore, the baud rate
// scan, a lost ack and a lost answer (both retransmitted), a board that never
// answers or speaks another protocol, and a state command's bytes as the board
// reads them.

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

constexpr KeyMask kA = 1u << 0;
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

Bytes message_bytes(const WiredStateMessage& message) {
  Bytes bytes(sizeof(message));
  std::memcpy(bytes.data(), &message, sizeof(message));
  return bytes;
}

// The board in NS1 Wired Pro Controller mode, as on console B: the session
// asks as the lab app's log of that board shows (protocol, id, firmware, name,
// logging flag, controller list, queue size, mode), changes the mode, and
// connects again.
void check_handshake_and_mode_change() {
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
  CHECK(info.mode_found == ControllerType::NintendoSwitch_WiredProController);
  CHECK(info.mode == ControllerType::NintendoSwitch_WiredController);
  CHECK(board.mode() == kWiredController);

  const std::vector<std::pair<std::uint8_t, std::uint8_t>> connect = {
      {PABB2_MESSAGE_OPCODE_PROTOCOL_VERSION, 0},
      {PABB2_MESSAGE_OPCODE_DEVICE_IDENTIFIER, 1},
      {PABB2_MESSAGE_OPCODE_FIRMWARE_VERSION, 2},
      {PABB2_MESSAGE_OPCODE_DEVICE_NAME, 3},
      {PABB2_MESSAGE_OPCODE_SET_LOGGING_FLAG, 0},
      {PABB2_MESSAGE_OPCODE_CONTROLLER_LIST, 4},
      {PABB2_MESSAGE_OPCODE_CQ_CAPACITY, 5},
      {PABB2_MESSAGE_OPCODE_READ_CONTROLLER_MODE, 6},
  };
  std::vector<std::pair<std::uint8_t, std::uint8_t>> expected = connect;
  expected.emplace_back(PABB2_MESSAGE_OPCODE_CHANGE_CONTROLLER_MODE, 0);
  expected.insert(expected.end(), connect.begin(), connect.end());
  // Status requests follow once the session runs.
  std::vector<std::pair<std::uint8_t, std::uint8_t>> sent;
  for (const BoardMessage& message : board.messages()) {
    if (sent.size() < expected.size()) {
      sent.emplace_back(message.opcode, message.id);
    }
  }
  CHECK(sent == expected);

  session.restore_mode();
  CHECK(board.mode() == kWiredProController);
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

// None leaves the board's mode alone (--board-check).
void check_keep_mode() {
  const Clock clock;
  FakeSwitch board(clock);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  const BoardInfo info = session.start(ControllerType::None);
  CHECK(info.mode == ControllerType::NintendoSwitch_WiredProController);
  CHECK(board.mode() == kWiredProController);
  for (const BoardMessage& message : board.messages()) {
    CHECK(message.opcode != PABB2_MESSAGE_OPCODE_CHANGE_CONTROLLER_MODE);
  }
  session.restore_mode();
  CHECK(board.mode() == kWiredProController);
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

// One A press for 100 ms, as the board reads the command: length 13, opcode
// 0x90, queue id 0, 100 ms, then the report (A is bit 2 of buttons0, the D-pad
// at rest is 8, the sticks centred at 0x80).
void check_state_bytes() {
  const Clock clock;
  FakeSwitch board(clock);
  BoardLog log(/*quiet=*/true);
  BoardSession session(board, log, quick_timings());
  session.start();
  session.send_state(wired_state_for_keys(kA), 100);
  const std::vector<BoardCommand> commands = wait_for_commands(board, 1);
  CHECK(commands.size() == 1);
  if (commands.size() == 1) {
    const Bytes expected = {0x0d, 0x00, 0x90, 0x00, 0x64, 0x00, 0x04,
                            0x00, 0x08, 0x80, 0x80, 0x80, 0x80};
    CHECK(message_bytes(commands[0].message) == expected);
  }
  // A hold past 65535 ms goes in two commands, as execute_state() splits it.
  session.send_state(neutral_wired_state(), 70000);
  const std::vector<BoardCommand> split = wait_for_commands(board, 3);
  CHECK(split.size() == 3);
  if (split.size() == 3) {
    CHECK(split[1].message.milliseconds == 65535);
    CHECK(split[2].message.milliseconds == 4465);
    CHECK(split[1].id == 1 && split[2].id == 2);
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
  session.send_state(wired_state_for_keys(kA), 10);
  for (int i = 0; i < 300 && board.retransmits_received() == 0; i++) {
    sleep_ms(10);
  }
  CHECK(board.retransmits_received() >= 1);
  CHECK(wait_for_commands(board, 1).size() == 1);

  // Lose the next ack and the finished report behind it.
  board.drop_next_sends(2);
  for (int i = 0; i < 5; i++) {
    session.send_state(wired_state_for_keys(kA), 10);
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
    CHECK(session.start(ControllerType::None).link_protocol == 2026061800);
  }
  {
    FakeSwitch board(clock);
    BoardSession session(board, log, quick_timings());
    board.drop_sends_after(1, 1);  // the reset's ack goes, the version's not
    CHECK(session.start(ControllerType::None).link_protocol == 2026061800);
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
  {
    FakeBoardProfile no_wired;
    no_wired.controllers = {0x0, 0x1100};
    FakeSwitch board(clock, no_wired);
    BoardSession session(board, log, quick_timings());
    bool threw = false;
    try {
      session.start();
    } catch (const BackendError& error) {
      threw = std::string(error.what()).find("does not offer") !=
              std::string::npos;
    }
    CHECK(threw);
    CHECK(board.mode() == kWiredProController);
  }
}

}  // namespace

int main() {
  check_handshake_and_mode_change();
  check_status();
  check_keep_mode();
  check_baud_scan();
  check_state_bytes();
  check_lost_ack_retransmits();
  check_lost_handshake_answers();
  check_errors();
  return TEST_RESULT();
}
