// A stand-in for the console, for tests, the latency harness and runs with no
// console: the controller board at the end of the serial port, and optionally
// the screen the capture card would show.
//
// The board decodes the controller's packets with CoreLib's PacketParser, runs
// each state command after the ones before it for its milliseconds (as the
// firmware's command queue does), and acks each packet from its own thread, as
// a real board answers on the serial reader thread. The screen is dark, and
// bright while a pressed state runs, shifted by a fixed response time.

#pragma once

#include <condition_variable>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <opencv2/core.hpp>
#include <thread>
#include <vector>

#include "clock.h"
#include "switch_controller.h"
#include "video_capture.h"

namespace gamepilot {

// One state command as the fake board ran it.
struct BoardCommand {
  double start_ms = 0;  // daemon clock
  double end_ms = 0;
  WiredState state{};
};

class FakeSwitch : public pa::UnreliableStreamSender,
                   private pa::PABotBase2::PacketRunner {
 public:
  FakeSwitch(const Clock& clock, std::uint32_t session_id);
  ~FakeSwitch();

  // Sends acks to `controller` until the returned handle is destroyed; keep it
  // in a scope inside the controller's.
  class Attachment {
   public:
    explicit Attachment(FakeSwitch& board) : board_(board) {}
    ~Attachment() { board_.set_controller(nullptr); }
    Attachment(const Attachment&) = delete;
    Attachment& operator=(const Attachment&) = delete;

   private:
    FakeSwitch& board_;
  };
  [[nodiscard]] Attachment attach(Pabb2Controller& controller) {
    set_controller(&controller);
    return Attachment(*this);
  }

  size_t unreliable_send(const void* data, size_t bytes) noexcept override;

  // Every state command received so far, in order.
  std::vector<BoardCommand> commands() const;

  // The screen: `frame_rate` frames per second of `size`, showing a press
  // `response_ms` after the board starts it. Valid while this FakeSwitch is.
  std::unique_ptr<FrameSource> screen(double frame_rate, double response_ms,
                                      cv::Size size);

  // Whether a pressed state runs at `t_ms`.
  bool pressed_at(double t_ms) const;

 private:
  void on_packet(const pa::PABotBase2::PacketHeader* packet) override;
  void ack_loop();
  void set_controller(Pabb2Controller* controller);

  const Clock& clock_;
  const std::uint32_t session_id_;
  // Held while an ack is handed to the controller, so detaching waits for it.
  // Never taken with lock_ held.
  std::mutex controller_lock_;
  Pabb2Controller* controller_ = nullptr;
  pa::PABotBase2::PacketParser parser_;

  mutable std::mutex lock_;
  std::condition_variable acks_ready_;
  std::deque<std::uint16_t>
      pending_acks_;  // seqnums, kResetAck bit set for a reset
  std::vector<BoardCommand> commands_;
  bool stop_ = false;
  std::thread ack_thread_;
};

}  // namespace gamepilot
