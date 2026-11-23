#include "fake_switch.h"

#include <algorithm>
#include <chrono>
#include <cstring>

namespace gamepilot {

namespace PB2 = pa::PABotBase2;

namespace {

// Collects what a PacketSender writes.
struct ByteSink : pa::UnreliableStreamSender {
  std::vector<std::uint8_t> bytes;
  size_t unreliable_send(const void* data, size_t size) noexcept override {
    const auto* begin = static_cast<const std::uint8_t*>(data);
    bytes.insert(bytes.end(), begin, begin + size);
    return size;
  }
};

// Opcode bits that mark an ack in the ack queue: the reset is acked with
// RET_RESET, stream data with RET_STREAM_DATA.
constexpr std::uint16_t kResetAck = 0x100;

constexpr std::uint8_t kDark = 16;
constexpr std::uint8_t kBright = 240;

bool is_pressed(const WiredState& state) {
  const WiredState neutral = neutral_wired_state();
  return std::memcmp(&state, &neutral, sizeof(state)) != 0;
}

class FakeScreen : public FrameSource {
 public:
  FakeScreen(const FakeSwitch& board, const Clock& clock, double frame_rate,
             double response_ms, cv::Size size)
      : board_(board),
        clock_(clock),
        frame_rate_(frame_rate),
        response_ms_(response_ms),
        size_(size) {}

  bool read(cv::Mat& frame) override {
    const double now = clock_.now_ms();
    if (frames_ == 0) {
      start_ms_ = now;
    }
    const double due =
        start_ms_ + static_cast<double>(frames_) * 1000.0 / frame_rate_;
    frames_++;
    if (due > now) {
      std::this_thread::sleep_for(
          std::chrono::duration<double, std::milli>(due - now));
    }
    const bool bright = board_.pressed_at(clock_.now_ms() - response_ms_);
    frame = cv::Mat(size_, CV_8UC3, cv::Scalar::all(bright ? kBright : kDark));
    return true;
  }

  double frame_rate() const override { return frame_rate_; }

 private:
  const FakeSwitch& board_;
  const Clock& clock_;
  double frame_rate_;
  double response_ms_;
  cv::Size size_;
  double start_ms_ = 0;
  long long frames_ = 0;
};

}  // namespace

FakeSwitch::FakeSwitch(const Clock& clock, std::uint32_t session_id)
    : clock_(clock), session_id_(session_id) {
  ack_thread_ = std::thread([this] { ack_loop(); });
}

FakeSwitch::~FakeSwitch() {
  {
    std::lock_guard<std::mutex> guard(lock_);
    stop_ = true;
  }
  acks_ready_.notify_all();
  ack_thread_.join();
}

size_t FakeSwitch::unreliable_send(const void* data, size_t bytes) noexcept {
  parser_.push_bytes(*this, session_id_, static_cast<const std::uint8_t*>(data),
                     bytes);
  return bytes;
}

void FakeSwitch::on_packet(const PB2::PacketHeader* packet) {
  const auto opcode =
      static_cast<std::uint8_t>(packet->opcode & PABB2_CONNECTION_OPCODE_MASK);
  // The reset's CRC is keyed by 0xffffffff, not the session id, so it arrives
  // as a checksum failure here; the board accepts it anyway.
  if (opcode == PABB2_CONNECTION_OPCODE_ASK_RESET) {
    std::lock_guard<std::mutex> guard(lock_);
    pending_acks_.push_back(
        static_cast<std::uint16_t>(packet->seqnum | kResetAck));
    acks_ready_.notify_one();
    return;
  }
  if (packet->magic_number != PABB2_PacketParser_RESULT_VALID ||
      opcode != PABB2_CONNECTION_OPCODE_ASK_STREAM_DATA) {
    return;
  }
  const std::size_t payload =
      packet->packet_bytes - sizeof(PB2::PacketHeaderData) - sizeof(uint32_t);
  const auto* message = reinterpret_cast<const std::uint8_t*>(packet) +
                        sizeof(PB2::PacketHeaderData);
  std::lock_guard<std::mutex> guard(lock_);
  if (payload == sizeof(WiredStateMessage) &&
      message[2] == PABB2_MESSAGE_CMD_NS_WIRED_CONTROLLER_STATE) {
    WiredStateMessage command;
    std::memcpy(&command, message, sizeof(command));
    const double now = clock_.now_ms();
    const double start =
        commands_.empty() ? now : std::max(now, commands_.back().end_ms);
    commands_.push_back(
        BoardCommand{start, start + command.milliseconds, command.report});
  }
  pending_acks_.push_back(packet->seqnum);
  acks_ready_.notify_one();
}

void FakeSwitch::ack_loop() {
  ByteSink sink;
  // Large (a 16 KB buffer), so on the heap.
  const auto sender =
      std::make_unique<PB2::PacketSender>(sink, 24, session_id_);
  std::unique_lock<std::mutex> guard(lock_);
  while (true) {
    acks_ready_.wait(guard, [&] { return stop_ || !pending_acks_.empty(); });
    if (stop_) {
      return;
    }
    const std::uint16_t ack = pending_acks_.front();
    pending_acks_.pop_front();
    guard.unlock();
    sink.bytes.clear();
    const auto opcode = static_cast<std::uint8_t>(
        (ack & kResetAck) != 0 ? PABB2_CONNECTION_OPCODE_RET_RESET
                               : PABB2_CONNECTION_OPCODE_RET_STREAM_DATA);
    sender->send_oob_packet_u32(static_cast<std::uint8_t>(ack), opcode, 0);
    {
      std::lock_guard<std::mutex> attached(controller_lock_);
      if (controller_ != nullptr) {
        controller_->receive(sink.bytes.data(), sink.bytes.size());
      }
    }
    guard.lock();
  }
}

void FakeSwitch::set_controller(Pabb2Controller* controller) {
  std::lock_guard<std::mutex> attached(controller_lock_);
  controller_ = controller;
}

std::vector<BoardCommand> FakeSwitch::commands() const {
  std::lock_guard<std::mutex> guard(lock_);
  return commands_;
}

bool FakeSwitch::pressed_at(double t_ms) const {
  std::lock_guard<std::mutex> guard(lock_);
  for (auto it = commands_.rbegin(); it != commands_.rend(); ++it) {
    if (it->start_ms <= t_ms) {
      return t_ms < it->end_ms && is_pressed(it->state);
    }
  }
  return false;
}

std::unique_ptr<FrameSource> FakeSwitch::screen(double frame_rate,
                                                double response_ms,
                                                cv::Size size) {
  return std::make_unique<FakeScreen>(*this, clock_, frame_rate, response_ms,
                                      size);
}

}  // namespace gamepilot
