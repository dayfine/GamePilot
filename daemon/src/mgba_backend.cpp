#include "mgba_backend.h"

#include <charconv>
#include <chrono>
#include <cstdio>
#include <opencv2/imgcodecs.hpp>
#include <sstream>
#include <thread>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"

namespace gamepilot {

namespace {

constexpr double kGbaFrameRate = 59.7275;
constexpr int kGbaWidth = 240;
constexpr int kGbaHeight = 160;

std::vector<std::string> split_words(const std::string& line) {
  std::vector<std::string> words;
  std::istringstream stream(line);
  std::string word;
  while (stream >> word) {
    words.push_back(word);
  }
  return words;
}

std::int64_t parse_int(const std::string& text, const std::string& reply) {
  std::int64_t value = 0;
  const auto [end, error] =
      std::from_chars(text.data(), text.data() + text.size(), value);
  if (error != std::errc() || end != text.data() + text.size()) {
    throw BackendError("bridge: unexpected reply: " + reply);
  }
  return value;
}

// "OK <F>" -> F
std::int64_t parse_ok_frame(const std::string& reply) {
  const auto words = split_words(reply);
  if (words.size() != 2 || words[0] != "OK") {
    throw BackendError("bridge: " + reply);
  }
  return parse_int(words[1], reply);
}

}  // namespace

MgbaBackend::MgbaBackend(std::uint16_t port) : socket_(connect_local(port)) {
  const std::string hello = command("HELLO 1");
  // OK 1 <code> <version> <mode>
  const auto words = split_words(hello);
  if (words.size() != 5 || words[0] != "OK" || words[1] != "1") {
    throw BackendError("bridge HELLO: " + hello);
  }
  if (words[4] != "paced") {
    throw BackendError("bridge runs in mode " + words[4] +
                       "; lockstep needs paced");
  }
  // The frame is the 240x160 GBA picture.
  info_ = BackendInfo{
      .kind = "mgba",
      .game_code = words[2],
      .frame_rate = kGbaFrameRate,
      .width = kGbaWidth,
      .height = kGbaHeight,
      .viewport = Viewport{Box{0, 0, 1, 1}, kGbaWidth, kGbaHeight},
      .timing = Timing::kLockstep,
      .takes_input = true};

  // GRANT 0 stalls the emulator at its next frame callback, since every frame
  // is >= 0. Give it a few frames to get there, then read the frame it holds
  // at.
  grant(0);
  std::this_thread::sleep_for(std::chrono::milliseconds(50));
  const std::int64_t first = grant(0);
  std::this_thread::sleep_for(std::chrono::milliseconds(20));
  seq_ = grant(0);
  if (seq_ != first) {
    throw BackendError(
        "bridge did not stall on GRANT 0; is another client pacing it?");
  }
}

MgbaBackend::~MgbaBackend() {
  try {
    release();
  } catch (const std::exception&) {
  }
}

std::string MgbaBackend::command(const std::string& line) {
  if (!socket_.valid()) {
    throw BackendError("bridge connection closed");
  }
  if (!socket_.send_all(line + "\n")) {
    throw BackendError("bridge connection lost");
  }
  while (true) {
    if (auto reply = lines_.next_line()) {
      if (reply->starts_with("ERR")) {
        // Name only the command: a LOAD line carries a path.
        throw BackendError("bridge: " + *reply + " (for " +
                           line.substr(0, line.find(' ')) + ")");
      }
      return *reply;
    }
    auto data = socket_.receive_some();
    if (!data) {
      socket_.close();
      throw BackendError("bridge connection lost");
    }
    lines_.append(*data);
  }
}

std::int64_t MgbaBackend::grant(std::int64_t frame) {
  return parse_ok_frame(command("GRANT " + std::to_string(frame)));
}

void MgbaBackend::set_keys(KeyMask mask) {
  const std::string reply =
      command("KEYS " + std::to_string(seq_) + " " + std::to_string(mask));
  if (reply.starts_with("LATE")) {
    late_keys_++;
    std::fprintf(stderr, "mgba: KEYS %lld %s\n", static_cast<long long>(seq_),
                 reply.c_str());
  } else if (reply != "OK") {
    throw BackendError("bridge KEYS: " + reply);
  }
}

std::int64_t MgbaBackend::step() {
  const std::int64_t target = seq_ + 1;
  // The bridge answers at once while it stalls and at the next frame hook while
  // it runs, so repeating the grant waits for the frame without a busy loop.
  std::int64_t current = grant(target);
  while (current < target) {
    current = grant(target);
  }
  if (current != target) {
    throw BackendError("emulator ran ahead: at " + std::to_string(current) +
                       ", granted " + std::to_string(target));
  }
  seq_ = current;
  return seq_;
}

cv::Mat MgbaBackend::frame() {
  const std::string reply = command("FRAME");
  // FRAME <F> <w> <h> <path, may contain spaces>
  std::istringstream stream(reply);
  std::string tag;
  std::string frame_text;
  int width = 0;
  int height = 0;
  stream >> tag >> frame_text >> width >> height;
  std::string path;
  std::getline(stream, path);
  const auto first = path.find_first_not_of(' ');
  path = first == std::string::npos ? std::string() : path.substr(first);
  if (tag != "FRAME" || path.empty()) {
    throw BackendError("bridge FRAME: " + reply);
  }
  const std::int64_t frame_seq = parse_int(frame_text, reply);
  if (frame_seq != seq_) {
    throw BackendError("bridge FRAME is frame " + frame_text + ", expected " +
                       std::to_string(seq_));
  }
  std::string bytes;
  if (!PokemonAutomation::file_to_string(path, bytes)) {
    throw BackendError("cannot read bridge frame file");
  }
  const cv::Mat encoded(1, static_cast<int>(bytes.size()), CV_8UC1,
                        const_cast<char*>(bytes.data()));
  cv::Mat image = cv::imdecode(encoded, cv::IMREAD_COLOR);
  if (image.empty() || image.cols != width || image.rows != height) {
    throw BackendError("cannot decode bridge frame PNG");
  }
  return image;
}

std::int64_t MgbaBackend::load_state(const std::string& path) {
  // LOAD clears queued KEYS and, with a grant active, holds at the loaded
  // frame.
  seq_ = parse_ok_frame(command("LOAD " + path));
  return seq_;
}

std::int64_t MgbaBackend::save_state(const std::string& path) {
  // SAVE replies with the current frame and leaves the grant as it is.
  parse_ok_frame(command("SAVE " + path));
  return seq_;
}

void MgbaBackend::release() {
  if (!socket_.valid()) {
    return;
  }
  try {
    command("BYE");
  } catch (const BackendError&) {
  }
  socket_.close();
}

}  // namespace gamepilot
