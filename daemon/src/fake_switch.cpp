#include "fake_switch.h"

#include <algorithm>
#include <chrono>
#include <cstring>

#include "Common/PABotBase2/PABotBase2_MessageProtocol.h"
#include "Common/PABotBase2/ReliableConnectionLayer/PABotBase2_PacketProtocol.h"

namespace gamepilot {

namespace PB2 = pa::PABotBase2;

namespace {

// The firmware retransmits its unacked stream every 50 ms
// (PABB2_ReliableConnectionFW_POLL_MS).
constexpr double kRetransmitMs = 50;

constexpr std::uint32_t kWiredProControllerMode = 0x1100;

// OemController_Status' bits (connected, ready, paired) and player 1's light,
// as a paired Pro Controller the console took reports them.
constexpr std::uint8_t kStatusConnected = 1u << 0;
constexpr std::uint8_t kStatusReady = 1u << 1;
constexpr std::uint8_t kStatusPaired = 1u << 2;
constexpr std::uint8_t kPlayer1Light = 0x01;

constexpr std::uint8_t kDark = 16;
constexpr std::uint8_t kBright = 240;

bool is_pressed(const ProButtons& buttons) {
  const ProButtons neutral = neutral_pro_buttons();
  return std::memcmp(&buttons, &neutral, sizeof(buttons)) != 0;
}

std::uint32_t read_u32(const std::uint8_t* bytes) {
  std::uint32_t value = 0;
  std::memcpy(&value, bytes, sizeof(value));
  return value;
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
    // The frame shows the screen at its own time, not when this thread woke:
    // a capture card keeps capturing while the host is stalled, so a late
    // read still gets the frames the console showed meanwhile.
    const bool bright = board_.pressed_at(due - response_ms_);
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

// Collects the packets a PacketSender writes, one per write.
struct PacketSink : pa::UnreliableStreamSender {
  std::vector<std::vector<std::uint8_t>> packets;
  size_t unreliable_send(const void* data, size_t size) noexcept override {
    const auto* begin = static_cast<const std::uint8_t*>(data);
    packets.emplace_back(begin, begin + size);
    return size;
  }
};

}  // namespace

// The board's side of the reliable link (run_recv_events()), on the board
// thread only. Messages the host's stream carries go to `on_message`.
class FakeSwitch::Link final : private PB2::PacketRunner {
 public:
  Link(FakeSwitch& board, const FakeBoardProfile& profile)
      : board_(board),
        profile_(profile),
        sender_(sink_, static_cast<std::uint8_t>(profile.packet_size)) {}

  // Retransmit flags of the packets in `bytes` are counted in `retransmits`.
  void receive(const std::vector<std::uint8_t>& bytes, int& retransmits) {
    retransmits_ = 0;
    parser_.push_bytes(*this, session_id_, bytes.data(), bytes.size());
    retransmits = retransmits_;
  }

  // Sends one message on the board's stream.
  void send_message(const void* message, std::size_t bytes) {
    sender_.send_stream_all_or_nothing(message, bytes);
  }

  void iterate_retransmits() { sender_.iterate_retransmits(); }
  bool has_unacked_sends() const { return sender_.slots_used() != 0; }

  std::vector<std::vector<std::uint8_t>> take_packets() {
    std::vector<std::vector<std::uint8_t>> packets;
    packets.swap(sink_.packets);
    return packets;
  }

 private:
  void on_packet(const PB2::PacketHeader* header) override {
    switch (header->magic_number) {
      case PABB2_PacketParser_RESULT_VALID:
        break;
      case PABB2_PacketParser_RESULT_INVALID:
        sender_.send_oob_packet_empty(header->seqnum,
                                      PABB2_CONNECTION_OPCODE_INVALID_LENGTH);
        return;
      case PABB2_PacketParser_RESULT_CHECKSUM_FAIL:
        sender_.send_oob_packet_empty(
            header->seqnum, PABB2_CONNECTION_OPCODE_INVALID_CHECKSUM_FAIL);
        return;
      default:
        return;
    }
    if ((header->opcode & PABB2_CONNECTION_RETRANSMIT_FLAG) != 0) {
      retransmits_++;
    }
    const auto opcode = static_cast<std::uint8_t>(
        header->opcode & PABB2_CONNECTION_OPCODE_MASK);
    switch (opcode) {
      case PABB2_CONNECTION_OPCODE_ASK_RESET:
        on_reset(header);
        return;
      case PABB2_CONNECTION_OPCODE_ASK_VERSION:
        answer(header, PABB2_CONNECTION_OPCODE_RET_VERSION,
               profile_.link_protocol);
        return;
      case PABB2_CONNECTION_OPCODE_ASK_PACKET_SIZE:
        answer(header, PABB2_CONNECTION_OPCODE_RET_PACKET_SIZE,
               profile_.packet_size);
        return;
      case PABB2_CONNECTION_OPCODE_ASK_BUFFER_SLOTS:
        answer(header, PABB2_CONNECTION_OPCODE_RET_BUFFER_SLOTS,
               profile_.buffer_slots);
        return;
      case PABB2_CONNECTION_OPCODE_ASK_BUFFER_BYTES:
        answer(header, PABB2_CONNECTION_OPCODE_RET_BUFFER_BYTES,
               PABB2_StreamCoalescer_BUFFER_SIZE);
        return;
      case PABB2_CONNECTION_OPCODE_ASK_STREAM_DATA:
        on_stream_data(header);
        return;
      case PABB2_CONNECTION_OPCODE_RET_STREAM_DATA:
        sender_.remove(header->seqnum);
        return;
      default:
        sender_.send_oob_packet_u32(header->seqnum,
                                    PABB2_CONNECTION_OPCODE_UNKNOWN_OPCODE,
                                    header->opcode);
    }
  }

  void on_reset(const PB2::PacketHeader* header) {
    if (header->packet_bytes < sizeof(PB2::PacketHeader_u32)) {
      return;
    }
    const auto* packet = reinterpret_cast<const PB2::PacketHeader_u32*>(header);
    // The firmware also resets its parser here; ours is between packets, and
    // the next ones in this chunk are read with the new session id.
    session_id_ = packet->data;
    sender_.reset(packet->data);
    coalescer_.reset();
    coalescer_.push_packet(0);
    stream_.clear();
    sender_.send_oob_packet_empty(header->seqnum,
                                  PABB2_CONNECTION_OPCODE_RET_RESET);
  }

  void answer(const PB2::PacketHeader* header, std::uint8_t opcode,
              std::uint32_t value) {
    coalescer_.push_packet(header->seqnum);
    sender_.send_oob_packet_u32(header->seqnum, opcode, value);
  }

  void on_stream_data(const PB2::PacketHeader* header) {
    if (!coalescer_.push_stream(
            reinterpret_cast<const PB2::PacketHeaderData*>(header))) {
      return;
    }
    sender_.send_oob_packet_u32(header->seqnum,
                                PABB2_CONNECTION_OPCODE_RET_STREAM_DATA,
                                coalescer_.free_bytes());
    std::uint8_t buffer[4096];
    const std::size_t bytes = coalescer_.read(buffer, sizeof(buffer));
    stream_.insert(stream_.end(), buffer, buffer + bytes);
    // Whole messages, each led by its 16-bit length.
    while (stream_.size() >= sizeof(PB2::MessageHeader)) {
      std::uint16_t length = 0;
      std::memcpy(&length, stream_.data(), sizeof(length));
      if (length < sizeof(PB2::MessageHeader) || stream_.size() < length) {
        return;
      }
      board_.on_message(stream_.data(), length);
      stream_.erase(stream_.begin(), stream_.begin() + length);
    }
  }

  FakeSwitch& board_;
  const FakeBoardProfile& profile_;
  PacketSink sink_;
  PB2::PacketSender sender_;
  PB2::PacketParser parser_;
  PB2::StreamCoalescer coalescer_;
  std::uint32_t session_id_ = 0;
  std::vector<std::uint8_t> stream_;
  int retransmits_ = 0;
};

FakeSwitch::FakeSwitch(const Clock& clock, FakeBoardProfile profile)
    : clock_(clock),
      profile_(std::move(profile)),
      link_(std::make_unique<Link>(*this, profile_)),
      mode_(profile_.mode) {
  board_thread_ = std::thread([this] { board_loop(); });
}

FakeSwitch::~FakeSwitch() {
  {
    std::lock_guard<std::mutex> guard(lock_);
    stop_ = true;
  }
  inbound_ready_.notify_all();
  board_thread_.join();
}

size_t FakeSwitch::unreliable_send(const void* data, size_t bytes) noexcept {
  const auto* begin = static_cast<const std::uint8_t*>(data);
  {
    std::lock_guard<std::mutex> guard(lock_);
    if (baud_rate_ != profile_.baud_rate) {
      return bytes;  // noise at the board's rate
    }
    inbound_.emplace_back(begin, begin + bytes);
  }
  inbound_ready_.notify_one();
  return bytes;
}

void FakeSwitch::set_baud_rate(std::uint32_t baud_rate) {
  std::lock_guard<std::mutex> guard(lock_);
  baud_rate_ = baud_rate;
}

void FakeSwitch::get_control_state(bool& dtr, bool& rts) {
  std::lock_guard<std::mutex> guard(lock_);
  dtr = dtr_;
  rts = rts_;
}

void FakeSwitch::set_control_state(bool dtr, bool rts) {
  std::lock_guard<std::mutex> guard(lock_);
  dtr_ = dtr;
  rts_ = rts;
}

void FakeSwitch::drop_sends_after(int pass, int count) {
  std::lock_guard<std::mutex> guard(lock_);
  pass_sends_ = pass;
  drop_sends_ = count;
}

int FakeSwitch::retransmits_received() const {
  std::lock_guard<std::mutex> guard(lock_);
  return retransmits_;
}

std::vector<BoardMessage> FakeSwitch::messages() const {
  std::lock_guard<std::mutex> guard(lock_);
  return messages_;
}

std::vector<BoardCommand> FakeSwitch::commands() const {
  std::lock_guard<std::mutex> guard(lock_);
  return commands_;
}

std::uint32_t FakeSwitch::mode() const {
  std::lock_guard<std::mutex> guard(lock_);
  return mode_;
}

// Called on the board thread, from Link.
void FakeSwitch::on_message(const std::uint8_t* message, std::size_t bytes) {
  PB2::MessageHeader header;
  std::memcpy(&header, message, sizeof(header));
  std::unique_lock<std::mutex> guard(lock_);
  messages_.push_back(BoardMessage{header.opcode, header.id});
  PB2::Message_u32 reply{};
  reply.message_bytes = sizeof(reply);
  reply.opcode = PABB2_MESSAGE_OPCODE_RET_U32;
  reply.id = header.id;
  std::vector<std::uint8_t> data;
  switch (header.opcode) {
    case PABB2_MESSAGE_OPCODE_PROTOCOL_VERSION:
      reply.data = profile_.device_protocol;
      break;
    case PABB2_MESSAGE_OPCODE_FIRMWARE_VERSION:
      reply.data = profile_.firmware_version;
      break;
    case PABB2_MESSAGE_OPCODE_DEVICE_IDENTIFIER:
      reply.data = profile_.device_id;
      break;
    case PABB2_MESSAGE_OPCODE_CQ_CAPACITY:
      reply.data = profile_.command_queue;
      break;
    case PABB2_MESSAGE_OPCODE_READ_CONTROLLER_MODE:
      reply.data = mode_;
      break;
    case PABB2_MESSAGE_OPCODE_REQUEST_STATUS:
      // The mode, then the Pro Controller's status (OemController_Status).
      reply.opcode = PABB2_MESSAGE_OPCODE_RET_U32_DATA;
      reply.data = mode_;
      if (mode_ == kWiredProControllerMode) {
        pa::NintendoSwitch::OemController_Status status{};
        status.status = profile_.console_sees_controller
                            ? (kStatusConnected | kStatusReady | kStatusPaired)
                            : kStatusPaired;
        status.player_lights =
            profile_.console_sees_controller ? kPlayer1Light : 0;
        data.resize(sizeof(status));
        std::memcpy(data.data(), &status, sizeof(status));
        reply.message_bytes =
            static_cast<std::uint16_t>(sizeof(reply) + data.size());
      }
      break;
    case PABB2_MESSAGE_OPCODE_DEVICE_NAME:
      data.assign(profile_.device_name.begin(), profile_.device_name.end());
      break;
    case PABB2_MESSAGE_OPCODE_CONTROLLER_LIST:
      data.resize(profile_.controllers.size() * sizeof(std::uint32_t));
      std::memcpy(data.data(), profile_.controllers.data(), data.size());
      break;
    case PABB2_MESSAGE_OPCODE_CHANGE_CONTROLLER_MODE:
    case PABB2_MESSAGE_OPCODE_RESET_TO_CONTROLLER:
      if (bytes >= sizeof(PB2::Message_u32)) {
        mode_ = read_u32(message + sizeof(PB2::MessageHeader));
      }
      return;
    case PABB2_MESSAGE_OPCODE_CQ_CANCEL:
      cancel_queued(clock_.now_ms());
      return;
    case PABB2_MESSAGE_OPCODE_CQ_REPLACE_ON_NEXT:
      replace_on_next_ = true;
      return;
    case PABB2_MESSAGE_CMD_NS1_OEM_CONTROLLER_BUTTONS:
      if (bytes == sizeof(ProButtonsMessage) &&
          mode_ == kWiredProControllerMode) {
        ProButtonsMessage command;
        std::memcpy(&command, message, sizeof(command));
        const double now = clock_.now_ms();
        if (replace_on_next_) {
          // The firmware's replace: the running state ends as this one
          // starts, the queued ones never run.
          cancel_queued(now);
          replace_on_next_ = false;
        }
        const double start =
            commands_.empty() ? now : std::max(now, commands_.back().end_ms);
        commands_.push_back(BoardCommand{
            start, start + command.milliseconds, command.id, command});
      }
      return;
    default:  // SET_LOGGING_FLAG and the rest: no answer
      return;
  }
  guard.unlock();
  if (header.opcode == PABB2_MESSAGE_OPCODE_DEVICE_NAME ||
      header.opcode == PABB2_MESSAGE_OPCODE_CONTROLLER_LIST) {
    PB2::MessageHeader head{};
    head.message_bytes =
        static_cast<std::uint16_t>(sizeof(PB2::MessageHeader) + data.size());
    head.opcode = PABB2_MESSAGE_OPCODE_RET_DATA;
    head.id = header.id;
    std::vector<std::uint8_t> out(sizeof(head));
    std::memcpy(out.data(), &head, sizeof(head));
    out.insert(out.end(), data.begin(), data.end());
    link_->send_message(out.data(), out.size());
    return;
  }
  std::vector<std::uint8_t> out(sizeof(reply));
  std::memcpy(out.data(), &reply, sizeof(reply));
  out.insert(out.end(), data.begin(), data.end());
  link_->send_message(out.data(), out.size());
}

// The firmware's cancel: the running state stops now, the queued ones never
// run, and none is reported finished (the host forgot them when it sent the
// cancel). Under lock_.
void FakeSwitch::cancel_queued(double now) {
  while (commands_.size() > finished_ && commands_.back().start_ms >= now) {
    commands_.pop_back();
  }
  if (commands_.size() > finished_) {
    commands_.back().end_ms = std::min(commands_.back().end_ms, now);
  }
  finished_ = commands_.size();
}

double FakeSwitch::next_finish_ms() const {
  return finished_ < commands_.size() ? commands_[finished_].end_ms : -1;
}

void FakeSwitch::finish_due_commands(double now) {
  std::vector<PB2::Message_u32> finished;
  {
    std::lock_guard<std::mutex> guard(lock_);
    while (finished_ < commands_.size() && commands_[finished_].end_ms <= now) {
      PB2::Message_u32 message{};
      message.message_bytes = sizeof(message);
      message.opcode = PABB2_MESSAGE_OPCODE_CQ_COMMAND_FINISHED;
      message.id = commands_[finished_].id;
      message.data = static_cast<std::uint32_t>(commands_[finished_].end_ms);
      finished.push_back(message);
      finished_++;
    }
  }
  for (const PB2::Message_u32& message : finished) {
    link_->send_message(&message, sizeof(message));
  }
}

void FakeSwitch::board_loop() {
  double next_retransmit = clock_.now_ms() + kRetransmitMs;
  std::unique_lock<std::mutex> guard(lock_);
  while (!stop_) {
    double wake = next_retransmit;
    if (next_finish_ms() >= 0) {
      wake = std::min(wake, next_finish_ms());
    }
    const double wait_ms = std::max(0.0, wake - clock_.now_ms());
    inbound_ready_.wait_for(
        guard, std::chrono::duration<double, std::milli>(wait_ms),
        [&] { return stop_ || !inbound_.empty(); });
    if (stop_) {
      return;
    }
    std::deque<std::vector<std::uint8_t>> inbound;
    inbound.swap(inbound_);
    guard.unlock();

    int retransmits = 0;
    for (const auto& bytes : inbound) {
      int seen = 0;
      link_->receive(bytes, seen);
      retransmits += seen;
    }
    const double now = clock_.now_ms();
    finish_due_commands(now);
    if (now >= next_retransmit) {
      link_->iterate_retransmits();
      next_retransmit = now + kRetransmitMs;
    }
    std::vector<std::vector<std::uint8_t>> packets = link_->take_packets();

    guard.lock();
    retransmits_ += retransmits;
    std::vector<std::vector<std::uint8_t>> delivered;
    for (auto& packet : packets) {
      if (pass_sends_ > 0) {
        pass_sends_--;
        delivered.push_back(std::move(packet));
      } else if (drop_sends_ > 0) {
        drop_sends_--;
      } else {
        delivered.push_back(std::move(packet));
      }
    }
    guard.unlock();
    for (const auto& packet : delivered) {
      on_unreliable_recv(packet.data(), packet.size());
    }
    guard.lock();
  }
}

bool FakeSwitch::pressed_at(double t_ms) const {
  std::lock_guard<std::mutex> guard(lock_);
  for (auto it = commands_.rbegin(); it != commands_.rend(); ++it) {
    if (it->start_ms <= t_ms) {
      return t_ms < it->end_ms && is_pressed(it->message.buttons);
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
