// The session with the PABotBase2 controller board, started as the C++ app
// starts it, and the controller states sent on it.
//
// Ported from the fork's SerialPABotBase2_Connection.cpp
// (SerialPrograms/Source/Controllers/PABotBase2/): connect_to_device() (the
// DTR/RTS steps and the ESP32 bootloader recovery), try_connect_to_device()
// (the baud rates, each tried with a 100 ms reset), open_serial_connection()
// (the link's version, packet size and buffer slots) and
// open_device_connection() (the board's queries). States go out as
// PABotBase2_ProController::execute_state() and
// PABotBase2_OemController::issue_report() (NintendoSwitch/Controllers/
// PABotBase2/) send them, in commands of at most 65535 ms through the board's
// command queue.
//
// Not ported, but used as they are from CoreLib: the reliable link
// (PABotBase2CC_ReliableStreamConnection.cpp: reset, the version check,
// retransmits) and the board's message layer (PABotBase2_DeviceHandle.cpp and
// PABotBase2_CommandQueueManager.cpp: the queries, the controller mode, the
// command queue).
//
// While connected, a thread asks the board for its status once a second, as
// ControllerStatusThread (Controllers/ControllerStatusThread.h) does through
// PABotBase2_OemController::update_status(): REQUEST_STATUS, answered with
// the mode and the controller's status (ready: the console sees it). Besides
// the status, that traffic is what wakes the link's retransmit thread:
// CoreLib's link only wakes it on an incoming ack, so a lost packet waits for
// the next one.
//
// The board's controller mode is only read, never set: start() fails unless
// the board already runs NS1 Wired Pro Controller, the mode the lab app keeps
// it in. So none of the C++'s mode change is ported
// (ControllerSession::set_controller(), and
// PABotBase2_OemController::run_preconnect_configure(), which the C++ runs
// only right before a mode change to write the controller's colours).
//
// Where this differs from the C++: the port is opened by the caller
// (SerialBoardPort); auto_select_controller_from_boot() is not run; the
// handshake's link requests wait at most 1 s for their answer and the
// connection is tried twice (the C++ waits forever: with no other traffic a
// lost answer is never asked again); a 0 ms state is still sent (release()
// needs the board to drop its keys), where issue_report() sends nothing; the
// status thread does not read the controller's colours (update_status() reads
// them once, for its status line) and logs nothing of the console's rumble or
// disconnect messages.

#pragma once

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "Common/Cpp/Concurrency/Backends/ThreadPool_Default.h"
#include "Common/Cpp/Logging/AbstractLogger.h"
#include "Common/Cpp/SerialConnection/SerialConnection.h"
#include "Common/Cpp/StreamConnections/PushingStreamConnections.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2CC_ReliableStreamConnection.h"
#include "Controllers/ControllerTypes.h"
#include "Controllers/PABotBase2/PABotBase2_DeviceHandle.h"
#include "switch_controller.h"

namespace gamepilot {

// A serial port as the session needs it: bytes both ways, the baud rate and
// the modem lines (SerialConnection's own calls).
class BoardPort : public pa::UnreliableStreamConnectionPushing {
 public:
  virtual void set_baud_rate(std::uint32_t baud_rate) = 0;
  virtual void get_control_state(bool& dtr, bool& rts) = 0;
  virtual void set_control_state(bool dtr, bool rts) = 0;
};

// CoreLib's SerialConnection as a BoardPort. Opening it opens the device.
class SerialBoardPort : public BoardPort, private pa::StreamListener {
 public:
  // `device` as the lab app names it ("cu.usbmodem..." or a /dev path).
  // Throws BackendError when the port does not open.
  explicit SerialBoardPort(const std::string& device);
  ~SerialBoardPort() override;

  size_t unreliable_send(const void* data, size_t bytes) noexcept override;
  void set_baud_rate(std::uint32_t baud_rate) override;
  void get_control_state(bool& dtr, bool& rts) override;
  void set_control_state(bool dtr, bool rts) override;

 private:
  void on_recv(const void* data, size_t bytes) override;

  pa::ThreadPool_Default pool_;
  std::unique_ptr<pa::SerialConnection> connection_;
};

// Log lines to stderr, each "board: ..."; none when quiet.
class BoardLog : public pa::Logger {
 public:
  explicit BoardLog(bool quiet = false) : quiet_(quiet) {}
  using pa::Logger::log;
  void log(const std::string& message, pa::Color color) override;

 private:
  bool quiet_;
};

// What start() learned.
struct BoardInfo {
  std::uint32_t baud_rate = 0;
  std::uint32_t link_protocol = 0;  // the reliable link's (RSC) version
  std::uint32_t device_protocol = 0;  // the message layer's (MLC) version
  std::uint32_t device_id = 0;
  std::uint32_t firmware_version = 0;
  std::string device_name;
  std::vector<pa::ControllerType> controllers;
  pa::ControllerType mode = pa::ControllerType::None;
};

std::string describe(const BoardInfo& info);

// The board's last status answer.
struct BoardStatus {
  bool answered = false;   // at least one status came back
  bool connected = false;  // the console sees the controller (ready)
  std::string error;       // why the status thread stopped, if it did
};

std::string describe(const BoardStatus& status);

struct BoardTimings {
  // SerialPABotBase2_Connection.cpp: the link retransmits after 80 ms, the
  // baud rates are tried for 3 s, then for 2 s after the bootloader recovery.
  pa::WallDuration retransmit = pa::Milliseconds(80);
  pa::WallDuration connect = pa::Milliseconds(3000);
  pa::WallDuration recovery = pa::Milliseconds(2000);
  // How long the modem lines settle between steps (wait_for(50ms)).
  pa::WallDuration settle = pa::Milliseconds(50);
  // ControllerStatusThread's PERIOD.
  pa::WallDuration status_period = pa::Milliseconds(1000);
  // How long a handshake request waits for its answer.
  pa::WallDuration answer = pa::Milliseconds(1000);
};

class BoardSession {
 public:
  BoardSession(BoardPort& port, pa::Logger& logger, BoardTimings timings = {});
  ~BoardSession();
  BoardSession(const BoardSession&) = delete;
  BoardSession& operator=(const BoardSession&) = delete;

  // Connects and checks the board runs NS1 Wired Pro Controller. Throws
  // BackendError when the board does not answer, speaks another protocol or
  // runs another mode (left as it is).
  BoardInfo start();

  // Holds `buttons` for `milliseconds` after the states sent before it.
  // Blocks while the board's command queue is full.
  void send_state(const ProButtons& buttons, std::uint32_t milliseconds);

  BoardStatus status() const;

  // Waits up to `timeout` for the first status answer; returns the status.
  BoardStatus first_status(pa::WallDuration timeout) const;

 private:
  void connect_once();
  void connect();
  void ask(std::uint8_t opcode, const char* what);
  void start_status_thread();
  void stop_status_thread();
  void status_loop();
  void update_status();
  bool try_connect_to_device(pa::WallDuration timeout);
  bool connect_to_device();
  void open_serial_connection();
  void open_device_connection();
  void close();

  BoardPort& port_;
  pa::Logger& logger_;
  BoardTimings timings_;
  pa::ThreadPool_Default pool_;
  std::unique_ptr<pa::PABotBase2::ReliableStreamConnection> link_;
  std::unique_ptr<pa::PABotBase2::DeviceHandle> device_;
  BoardInfo info_;

  mutable std::mutex status_lock_;
  std::condition_variable status_wake_;
  bool status_stop_ = false;
  BoardStatus status_;
  std::thread status_thread_;
};

}  // namespace gamepilot
