#include "gzip_reader.h"

#include "Common/Cpp/Filesystem/FileIO.h"

#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#include "miniz-3.1.1/miniz.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

namespace {

constexpr std::size_t kInputBytes = 1 << 16;
// The fixed part of a gzip header (RFC 1952): magic, method, flags, mtime,
// extra flags, OS.
constexpr std::size_t kFixedHeader = 10;
constexpr unsigned char kMagic1 = 0x1f;
constexpr unsigned char kMagic2 = 0x8b;
constexpr unsigned char kDeflate = 8;
constexpr unsigned char kFlagHeaderCrc = 2;
constexpr unsigned char kFlagExtra = 4;
constexpr unsigned char kFlagName = 8;
constexpr unsigned char kFlagComment = 16;

// Where the deflate stream starts in `head`, or 0 if it is not gzip (or its
// header does not fit).
std::size_t deflate_start(const std::string& head) {
  const auto byte = [&](std::size_t i) {
    return static_cast<unsigned char>(head[i]);
  };
  if (head.size() < kFixedHeader || byte(0) != kMagic1 || byte(1) != kMagic2 ||
      byte(2) != kDeflate) {
    return 0;
  }
  const unsigned char flags = byte(3);
  std::size_t at = kFixedHeader;
  if ((flags & kFlagExtra) != 0) {
    if (at + 2 > head.size()) {
      return 0;
    }
    at += 2 + (static_cast<std::size_t>(byte(at)) |
               static_cast<std::size_t>(byte(at + 1)) << 8);
  }
  for (const unsigned char text : {kFlagName, kFlagComment}) {
    if ((flags & text) != 0) {
      at = head.find('\0', at);
      if (at == std::string::npos) {
        return 0;
      }
      at++;
    }
  }
  if ((flags & kFlagHeaderCrc) != 0) {
    at += 2;
  }
  return at < head.size() ? at : 0;
}

}  // namespace

struct GzipReader::State {
  pa::FileIO file;
  std::string input;
  mz_stream stream{};
  bool started = false;
  bool ended = false;

  ~State() {
    if (started) {
      mz_inflateEnd(&stream);
    }
  }

  // Reads the next input chunk; false at the end of the file.
  bool fill() {
    input.resize(kInputBytes);
    input.resize(file.read(input.data(), input.size()));
    stream.next_in = reinterpret_cast<const unsigned char*>(input.data());
    stream.avail_in = static_cast<unsigned int>(input.size());
    return !input.empty();
  }
};

GzipReader::GzipReader() : state_(std::make_unique<State>()) {}
GzipReader::~GzipReader() = default;

bool GzipReader::open(const std::string& path) {
  State& s = *state_;
  if (!s.file.open(path, pa::FileMode::READ | pa::FileMode::BINARY) ||
      !s.fill()) {
    return false;
  }
  const std::size_t start = deflate_start(s.input);
  if (start == 0 || mz_inflateInit2(&s.stream, -MZ_DEFAULT_WINDOW_BITS) !=
                        MZ_OK) {
    return false;
  }
  s.started = true;
  s.stream.next_in += start;
  s.stream.avail_in -= static_cast<unsigned int>(start);
  return true;
}

std::size_t GzipReader::read(char* out, std::size_t size) {
  State& s = *state_;
  if (!s.started || s.ended) {
    return 0;
  }
  s.stream.next_out = reinterpret_cast<unsigned char*>(out);
  s.stream.avail_out = static_cast<unsigned int>(size);
  while (s.stream.avail_out > 0) {
    if (s.stream.avail_in == 0 && !s.fill()) {
      s.ended = true;
      break;
    }
    const int status = mz_inflate(&s.stream, MZ_NO_FLUSH);
    if (status == MZ_STREAM_END ||
        (status != MZ_OK && status != MZ_BUF_ERROR)) {
      s.ended = true;
      break;
    }
  }
  return size - s.stream.avail_out;
}

}  // namespace gamepilot
