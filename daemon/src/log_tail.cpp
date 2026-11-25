#include "log_tail.h"

#include <algorithm>
#include <cstdio>
#include <exception>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

namespace {

// Read at most this much in one poll.
constexpr std::uint64_t kMaxReadBytes = 1024 * 1024;

}  // namespace

std::vector<std::string> LogTail::poll() {
  std::vector<std::string> lines;
  std::uint64_t size = 0;
  try {
    if (!pa::Filesystem::exists(path_)) {
      return lines;
    }
    size = static_cast<std::uint64_t>(pa::Filesystem::file_size(path_));
  } catch (const std::exception&) {
    return lines;
  }
  if (!started_ || size < offset_) {
    started_ = true;
    offset_ = size > backlog_bytes_ ? size - backlog_bytes_ : 0;
    skip_partial_ = offset_ > 0;
    partial_.clear();
  }
  if (size == offset_) {
    return lines;
  }
  pa::FileIO file;
  if (!file.open(path_, pa::FileMode::READ | pa::FileMode::BINARY) ||
      !file.seek(static_cast<std::int64_t>(offset_), SEEK_SET)) {
    return lines;
  }
  std::string chunk(static_cast<std::size_t>(
                        std::min(size - offset_, kMaxReadBytes)),
                    '\0');
  chunk.resize(file.read(chunk.data(), chunk.size()));
  offset_ += chunk.size();
  if (skip_partial_) {
    const std::size_t end = chunk.find('\n');
    if (end == std::string::npos) {
      return lines;
    }
    chunk.erase(0, end + 1);
    skip_partial_ = false;
  }
  partial_ += chunk;
  std::size_t start = 0;
  for (std::size_t end = partial_.find('\n'); end != std::string::npos;
       end = partial_.find('\n', start)) {
    std::string line = partial_.substr(start, end - start);
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    if (line.size() > kLogTailMaxLine) {
      line.resize(kLogTailMaxLine);
    }
    lines.push_back(std::move(line));
    start = end + 1;
  }
  partial_.erase(0, start);
  return lines;
}

}  // namespace gamepilot
