// A stand-in for the console, for tests, the latency harness and runs with no
// console: the controller board at the end of the serial port, and optionally
// the screen the capture card would show.
//
// The board's link layer is a port of the firmware side of the reliable link,
// PABotBase2FW_ReliableStreamConnection.cpp's run_recv_events() (Common/
// PABotBase2/ReliableConnectionLayer/): the reset, the version, packet size
// and buffer slot answers, stream acks with the free bytes, and its own
// stream retransmitted every 50 ms (run_send_events()). Its packets are built
// by CoreLib's PacketSender, as the firmware's are. The message layer answers
// the queries PABotBase2_DeviceHandle.cpp makes, in the shapes it reads
// (RET_U32 / RET_DATA with the request's id), takes a controller mode change
// (which the session never sends), and in NS1 Wired Pro Controller mode runs
// Pro Controller button reports back to back as the firmware's command queue
// does, reporting each as finished (CQ_COMMAND_FINISHED) when it ends. The
// firmware's own message layer is not in Arduino-Source, so these answers come
// from the C++ side that reads them and from the lab app's log of console B's
// board.
//
// Everything the board does runs on its own thread, as a real board answers on
// the serial reader thread. The screen is dark, and bright while a pressed
// state runs, shifted by a fixed response time.

#pragma once

#include <condition_variable>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <opencv2/core.hpp>
#include <string>
#include <thread>
#include <vector>

#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketParser.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketSender.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_StreamCoalescer.h"
#include "board_session.h"
#include "clock.h"
#include "switch_controller.h"
#include "video_capture.h"

namespace gamepilot {

// What the board answers. The defaults are console B's board as the lab app's
// log shows it (2026-11): an ESP32-S3 in NS1 Wired Pro Controller mode.
struct FakeBoardProfile {
  std::uint32_t baud_rate = 921600;  // it hears nothing at another rate
  std::uint32_t link_protocol = 2026061800;
  std::uint32_t packet_size = 64;
  std::uint32_t buffer_slots = 128;
  std::uint32_t device_protocol = 2026061805;
  std::uint32_t device_id = 0x12;
  std::uint32_t firmware_version = 2026092800;
  std::string device_name = "PABotBase2-ESP32-S3";
  std::vector<std::uint32_t> controllers = {0x0,    0x100,  0x1000, 0x1010,
                                            0x1100, 0x1101, 0x1102};
  std::uint32_t command_queue = 255;
  std::uint32_t mode = 0x1100;
  bool console_sees_controller = true;  // the status' ready bit
};

// One state command as the fake board ran it.
struct BoardCommand {
  double start_ms = 0;  // daemon clock
  double end_ms = 0;
  std::uint8_t id = 0;
  ProButtonsMessage message{};
};

// One message the host sent, as the board read it.
struct BoardMessage {
  std::uint8_t opcode = 0;
  std::uint8_t id = 0;
};

class FakeSwitch : public BoardPort {
 public:
  explicit FakeSwitch(const Clock& clock, FakeBoardProfile profile = {});
  ~FakeSwitch() override;
  FakeSwitch(const FakeSwitch&) = delete;
  FakeSwitch& operator=(const FakeSwitch&) = delete;

  size_t unreliable_send(const void* data, size_t bytes) noexcept override;
  void set_baud_rate(std::uint32_t baud_rate) override;
  void get_control_state(bool& dtr, bool& rts) override;
  void set_control_state(bool dtr, bool rts) override;

  // Loses the next `count` packets the board sends, as a noisy line would.
  void drop_next_sends(int count) { drop_sends_after(0, count); }
  // Lets `pass` packets through, then loses `count`.
  void drop_sends_after(int pass, int count);

  // Packets that arrived with the retransmit flag.
  int retransmits_received() const;
  // Every message the host sent, in order.
  std::vector<BoardMessage> messages() const;
  // Every state command received so far, in order.
  std::vector<BoardCommand> commands() const;
  std::uint32_t mode() const;

  // The screen: `frame_rate` frames per second of `size`, showing a press
  // `response_ms` after the board starts it. Valid while this FakeSwitch is.
  std::unique_ptr<FrameSource> screen(double frame_rate, double response_ms,
                                      cv::Size size);

  // Whether a pressed state runs at `t_ms`.
  bool pressed_at(double t_ms) const;

 private:
  class Link;
  void board_loop();
  void on_message(const std::uint8_t* message, std::size_t bytes);
  void finish_due_commands(double now);
  void cancel_queued(double now);
  double next_finish_ms() const;

  const Clock& clock_;
  const FakeBoardProfile profile_;
  std::unique_ptr<Link> link_;  // board thread only

  mutable std::mutex lock_;
  std::condition_variable inbound_ready_;
  std::deque<std::vector<std::uint8_t>> inbound_;
  std::uint32_t baud_rate_ = 0;
  bool dtr_ = false;
  bool rts_ = false;
  int pass_sends_ = 0;
  int drop_sends_ = 0;
  int retransmits_ = 0;
  std::uint32_t mode_ = 0;
  std::vector<BoardMessage> messages_;
  std::vector<BoardCommand> commands_;
  std::size_t finished_ = 0;  // commands_ reported finished
  bool stop_ = false;
  std::thread board_thread_;
};

}  // namespace gamepilot
