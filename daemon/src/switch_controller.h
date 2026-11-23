// The Switch's input sink: a wired controller on a PABotBase2 microcontroller,
// spoken to over a serial port. The wire format is CoreLib's own: a controller
// state message (Common/PABotBase2/Controllers/
// PABotBase2_Controller_NS_WiredController.h) sent on the reliable stream, cut
// into CRC-checked packets by CoreLib's PacketSender
// (Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketSender.cpp).
//
// The serial port is CoreLib's UnreliableStreamSender: CoreLib's
// SerialConnection on a console, RecordingSerialPort in tests.
//
// Acks from the device come in through receive(), parsed by CoreLib's
// PacketParser, as PABotBase2CC_ReliableStreamConnection.cpp's on_packet()
// does. Not here yet (needs the console): retransmits, and the session
// handshake the C++ app runs first (version, packet size, then the controller
// mode).

#pragma once

#include <cstdint>
#include <mutex>
#include <vector>

#include "Common/ControllerStates/NintendoSwitch_WiredController_State.h"
#include "Common/Cpp/StreamConnections/StreamInterface.h"
#include "Common/PABotBase2/Controllers/PABotBase2_Controller_NS_WiredController.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketParser.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketSender.h"
#include "backend.h"
#include "clock.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

using WiredState = ::pabb_NintendoSwitch_WiredController_State;
using WiredStateMessage =
    pa::PABotBase2::pabb2_Message_Command_NS_WiredController_State;

// Nothing pressed, sticks centred (the C++'s NEUTRAL_STATE in
// Common/ControllerStates/NintendoSwitch_WiredController_State.c, which CoreLib
// does not compile).
WiredState neutral_wired_state();

// The wired controller state for GBA keys as the Switch's GBA app reads them:
// A, B, L, R as themselves, Start as Plus, Select as Minus, the arrows as the
// D-pad. Opposite arrows cancel, as in the C++'s execute_state()
// (NintendoSwitch_PABotBase2_WiredController.cpp).
WiredState wired_state_for_keys(KeyMask keys);

// One state command: hold `state` for `milliseconds` (the device runs queued
// commands back to back). `id` is the command queue's sequence number.
WiredStateMessage wired_state_message(const WiredState& state,
                                      std::uint16_t milliseconds,
                                      std::uint8_t id);

// Sends controller states on one PABotBase2 session. Packets go out as CoreLib
// builds them, at most 24 bytes each (the C++ app's packet size), so one state
// is one packet. Thread-safe: acks arrive on the serial port's reader thread.
class Pabb2Controller : private pa::PABotBase2::PacketRunner {
 public:
  Pabb2Controller(pa::UnreliableStreamSender& port, std::uint32_t session_id);

  // Starts the session: the reset packet that announces `session_id`.
  void reset();

  // Queues `state` for `milliseconds` (longer holds are split into 65535 ms
  // commands, as the C++ does). Returns false when the unacknowledged window
  // is full.
  bool send_state(const WiredState& state, std::uint32_t milliseconds);

  // Bytes the device sent: its acks free their packets' slots.
  void receive(const void* data, size_t bytes);

  // Packets sent and not acknowledged yet.
  std::uint8_t unacknowledged() const;

 private:
  void on_packet(const pa::PABotBase2::PacketHeader* packet) override;

  mutable std::mutex lock_;
  pa::PABotBase2::PacketSender sender_;
  pa::PABotBase2::PacketParser parser_;
  std::uint8_t next_command_id_ = 0;
};

// A fake serial port: keeps every write with the time it was made.
class RecordingSerialPort : public pa::UnreliableStreamSender {
 public:
  struct Write {
    double t_ms = 0;
    std::vector<std::uint8_t> bytes;
  };

  explicit RecordingSerialPort(const Clock& clock) : clock_(clock) {}

  size_t unreliable_send(const void* data, size_t bytes) noexcept override;

  std::vector<Write> writes() const;

 private:
  const Clock& clock_;
  mutable std::mutex lock_;
  std::vector<Write> writes_;
};

}  // namespace gamepilot
