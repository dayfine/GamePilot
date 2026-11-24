#include "board_session.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>

#include "Common/Cpp/Exceptions.h"
#include "Common/PABotBase2/PABotBase2_MessageProtocol.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketProtocol.h"
#include "Common/SerialPABotBase/SerialPABotBase_Protocol_IDs.h"
#include "Controllers/ControllerTypeStrings.h"
#include "backend.h"

namespace gamepilot {

namespace PB2 = pa::PABotBase2;

namespace {

// SerialPABotBase2_Connection.cpp: open_serial_port() opens at 115200, then
// try_connect_to_device() tries these.
constexpr std::uint32_t kOpenBaudRate = 115200;
constexpr std::uint32_t kBaudRates[] = {921600, 115200};
constexpr auto kResetTimeout = pa::Milliseconds(100);

// The only mode GamePilot drives the board in.
constexpr pa::ControllerType kProControllerMode =
    pa::ControllerType::NintendoSwitch_WiredProController;

// OemController_Status' bit the console sets once it takes the controller
// (update_status(): "Connected" when ready).
constexpr std::uint8_t kStatusReady = 1u << 1;

// The longest hold one command carries.
constexpr std::uint32_t kMaxCommandMs = 65535;

std::string mode_name(pa::ControllerType mode) {
  return pa::CONTROLLER_TYPE_STRINGS.get_string(mode);
}

}  // namespace

SerialBoardPort::SerialBoardPort(const std::string& device)
    : pool_([] {}, 0) {
  try {
    connection_ =
        std::make_unique<pa::SerialConnection>(pool_, device, kOpenBaudRate);
  } catch (const pa::Exception& e) {
    pool_.stop();
    throw BackendError("serial port " + device + ": " + e.message());
  }
  connection_->add_listener(*this);
}

SerialBoardPort::~SerialBoardPort() {
  connection_->remove_listener(*this);
  connection_.reset();
  pool_.stop();
}

size_t SerialBoardPort::unreliable_send(const void* data,
                                        size_t bytes) noexcept {
  // SerialConnection makes it private; it is public on the interface.
  pa::UnreliableStreamSender& sender = *connection_;
  return sender.unreliable_send(data, bytes);
}

void SerialBoardPort::set_baud_rate(std::uint32_t baud_rate) {
  connection_->set_baud_rate(baud_rate);
}

void SerialBoardPort::get_control_state(bool& dtr, bool& rts) {
  connection_->get_control_state(dtr, rts);
}

void SerialBoardPort::set_control_state(bool dtr, bool rts) {
  connection_->set_control_state(dtr, rts);
}

void SerialBoardPort::on_recv(const void* data, size_t bytes) {
  on_unreliable_recv(data, bytes);
}

void BoardLog::log(const std::string& message, pa::Color) {
  if (!quiet_) {
    std::fprintf(stderr, "board: %s\n", message.c_str());
  }
}

std::string describe(const BoardInfo& info) {
  return info.device_name + ", firmware " +
         std::to_string(info.firmware_version) + ", link " +
         std::to_string(info.link_protocol) + ", messages " +
         std::to_string(info.device_protocol) + ", " +
         std::to_string(info.baud_rate) + " baud, mode " + mode_name(info.mode);
}

BoardSession::BoardSession(BoardPort& port, pa::Logger& logger,
                           BoardTimings timings)
    : port_(port), logger_(logger), timings_(timings), pool_([] {}, 0) {}

BoardSession::~BoardSession() {
  close();
  pool_.stop();
}

void BoardSession::close() {
  stop_status_thread();
  device_.reset();
  link_.reset();
}

void BoardSession::ask(std::uint8_t opcode, const char* what) {
  link_->send_request(opcode);
  if (!link_->wait_for_pending(timings_.answer)) {
    throw BackendError(std::string("board: no answer to ") + what);
  }
}

void BoardSession::start_status_thread() {
  stop_status_thread();
  {
    std::lock_guard<std::mutex> guard(status_lock_);
    status_stop_ = false;
    status_ = BoardStatus{};
  }
  status_thread_ = std::thread([this] { status_loop(); });
}

void BoardSession::stop_status_thread() {
  {
    std::lock_guard<std::mutex> guard(status_lock_);
    status_stop_ = true;
  }
  status_wake_.notify_all();
  if (status_thread_.joinable()) {
    status_thread_.join();
  }
}

void BoardSession::update_status() {
  PB2::MessageHeader request{};
  request.message_bytes = sizeof(request);
  request.opcode = PABB2_MESSAGE_OPCODE_REQUEST_STATUS;
  const std::uint8_t id = device_->send_request_with_response(request);
  const std::string response =
      device_->wait_for_request_response_min_size<
          PB2::Message_u32, PABB2_MESSAGE_OPCODE_RET_U32_DATA>(id);
  PB2::Message_u32 header{};
  std::memcpy(&header, response.data(), sizeof(header));
  std::lock_guard<std::mutex> guard(status_lock_);
  status_.answered = true;
  // Only the OEM controllers carry their status.
  switch (header.data) {
    case PABB_CID_NintendoSwitch_WiredProController:
    case PABB_CID_NintendoSwitch_WiredLeftJoycon:
    case PABB_CID_NintendoSwitch_WiredRightJoycon:
    case PABB_CID_NintendoSwitch_WirelessProController:
    case PABB_CID_NintendoSwitch_WirelessLeftJoycon:
    case PABB_CID_NintendoSwitch_WirelessRightJoycon:
      break;
    default:
      status_.connected = false;
      return;
  }
  constexpr std::size_t kExpected =
      sizeof(PB2::Message_u32) +
      sizeof(pa::NintendoSwitch::OemController_Status);
  if (response.size() != kExpected) {
    throw BackendError("board: status of the wrong size " +
                       std::to_string(response.size()));
  }
  pa::NintendoSwitch::OemController_Status controller{};
  std::memcpy(&controller, response.data() + sizeof(PB2::Message_u32),
              sizeof(controller));
  status_.connected = (controller.status & kStatusReady) != 0;
}

void BoardSession::status_loop() {
  auto next = std::chrono::steady_clock::now();
  while (true) {
    try {
      update_status();
    } catch (const std::exception& e) {
      std::lock_guard<std::mutex> guard(status_lock_);
      status_.error = e.what();
      return;
    } catch (const pa::Exception& e) {
      std::lock_guard<std::mutex> guard(status_lock_);
      status_.error = e.message();
      return;
    }
    next += timings_.status_period;
    std::unique_lock<std::mutex> guard(status_lock_);
    if (status_wake_.wait_until(guard, next, [&] { return status_stop_; })) {
      return;
    }
  }
}

BoardStatus BoardSession::first_status(pa::WallDuration timeout) const {
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (std::chrono::steady_clock::now() < deadline) {
    const BoardStatus now = status();
    if (now.answered || !now.error.empty()) {
      return now;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  return status();
}

std::string describe(const BoardStatus& status) {
  if (!status.error.empty()) {
    return "status failed: " + status.error;
  }
  if (!status.answered) {
    return "no status answer";
  }
  return status.connected ? "the console sees the controller"
                          : "the console does NOT see the controller";
}

BoardStatus BoardSession::status() const {
  std::lock_guard<std::mutex> guard(status_lock_);
  return status_;
}

bool BoardSession::try_connect_to_device(pa::WallDuration timeout) {
  bool dtr = false;
  bool rts = false;
  port_.get_control_state(dtr, rts);
  logger_.log("DTR = " + std::to_string(dtr) + ", RTS = " +
              std::to_string(rts));
  const pa::WallClock deadline = pa::current_time() + timeout;
  do {
    for (const std::uint32_t baud_rate : kBaudRates) {
      logger_.log("Trying baud " + std::to_string(baud_rate) +
                  " (with session ID)...");
      port_.set_baud_rate(baud_rate);
      if (link_->reset(kResetTimeout)) {
        info_.baud_rate = baud_rate;
        return true;
      }
    }
  } while (pa::current_time() < deadline);
  return false;
}

bool BoardSession::connect_to_device() {
  // ESP32 needs to avoid (DTR=0, RTS=1) as that resets the board; bring the
  // lines to DTR=1, RTS=0 one at a time.
  bool dtr = false;
  bool rts = false;
  port_.get_control_state(dtr, rts);
  if (rts) {
    std::this_thread::sleep_for(timings_.settle);
    rts = false;
    port_.set_control_state(dtr, rts);
  }
  if (!dtr) {
    std::this_thread::sleep_for(timings_.settle);
    dtr = true;
    port_.set_control_state(dtr, rts);
  }
  if (try_connect_to_device(timings_.connect)) {
    return true;
  }
  // Forces an ESP32 out of its bootloader: (0, 1) -> (1, 1) -> (1, 0).
  logger_.log("Forcing RTS -> true");
  port_.set_control_state(false, true);
  std::this_thread::sleep_for(timings_.settle);
  port_.set_control_state(true, true);
  std::this_thread::sleep_for(timings_.settle);
  port_.set_control_state(true, false);
  const bool success = try_connect_to_device(timings_.recovery);
  port_.set_control_state(true, false);
  return success;
}

void BoardSession::open_serial_connection() {
  link_ = std::make_unique<PB2::ReliableStreamConnection>(
      nullptr, logger_, false, pool_, port_, timings_.retransmit, nullptr);
  if (!connect_to_device()) {
    throw BackendError(
        "board: no answer to the reset at any baud rate (is the board "
        "flashed with PABotBase2, and the port right?)");
  }
  ask(PABB2_CONNECTION_OPCODE_ASK_VERSION, "the version request");
  info_.link_protocol = link_->remote_protocol();
  if (!link_->remote_protocol_is_compatible()) {
    throw BackendError("board: incompatible link protocol " +
                       std::to_string(link_->remote_protocol()));
  }
  if (!link_->error_string().empty()) {
    throw BackendError("board: " + link_->error_string());
  }
  ask(PABB2_CONNECTION_OPCODE_ASK_PACKET_SIZE, "the packet size request");
  ask(PABB2_CONNECTION_OPCODE_ASK_BUFFER_SLOTS, "the buffer slots request");
}

void BoardSession::open_device_connection() {
  device_ = std::make_unique<PB2::DeviceHandle>(nullptr, logger_, *link_);
  device_->connect();
  info_.device_protocol = device_->device_protocol_version();
  info_.device_id = device_->device_id();
  info_.firmware_version = device_->device_firmware_version();
  info_.device_name = device_->device_name();
  info_.controllers = device_->controller_list();
  info_.mode = device_->refresh_controller_type();
}

void BoardSession::connect_once() {
  close();
  try {
    open_serial_connection();
    open_device_connection();
  } catch (const pa::Exception& e) {
    throw BackendError("board: " + e.message());
  }
}

void BoardSession::connect() {
  try {
    connect_once();
  } catch (const BackendError& e) {
    logger_.log(std::string(e.what()) + "; connecting again");
    connect_once();
  }
}

BoardInfo BoardSession::start() {
  connect();
  if (info_.mode != kProControllerMode) {
    throw BackendError(
        "board: runs " + mode_name(info_.mode) + ", not " +
        mode_name(kProControllerMode) +
        "; GamePilot never changes the mode: pick that controller in the lab "
        "app's panel");
  }
  start_status_thread();
  return info_;
}

void BoardSession::send_state(const ProButtons& buttons,
                              std::uint32_t milliseconds) {
  if (device_ == nullptr) {
    throw BackendError("board: not connected");
  }
  try {
    do {
      const std::uint32_t chunk = std::min(milliseconds, kMaxCommandMs);
      ProButtonsMessage message =
          pro_buttons_message(buttons, static_cast<std::uint16_t>(chunk));
      device_->command_queue().send_command(nullptr, message);
      milliseconds -= chunk;
    } while (milliseconds > 0);
  } catch (const pa::Exception& e) {
    throw BackendError("board: " + e.message());
  }
}

void BoardSession::cancel_queued() {
  if (device_ == nullptr) {
    throw BackendError("board: not connected");
  }
  PB2::CommandQueueManager& queue = device_->command_queue();
  if (queue.send_cancel() ==
      PB2::CommandQueueManager::SUPPRESSED_DUPLICATE) {
    return;  // nothing queued, or a cancel already on its way
  }
  try {
    if (!queue.wait_for_cancel(timings_.answer)) {
      throw BackendError("board: the cancel was not taken");
    }
  } catch (const pa::Exception& e) {
    throw BackendError("board: " + e.message());
  }
}

}  // namespace gamepilot
