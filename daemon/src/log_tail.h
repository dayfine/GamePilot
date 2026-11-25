// Follows a text log another program writes (--tail-log: PA/CC's
// SerialPrograms-<start>.log), read only: each poll returns the whole lines
// added since the last one. It starts near the end (the last `backlog_bytes`,
// from the first whole line in them), so a new watch page gets some context,
// and starts over when the file shrinks (replaced or truncated). A missing
// file gives no lines until it appears.

#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace gamepilot {

constexpr std::uint64_t kLogTailBacklogBytes = 16 * 1024;
// Longer lines are cut to this many bytes.
constexpr std::size_t kLogTailMaxLine = 2000;

class LogTail {
 public:
  explicit LogTail(std::string path,
                   std::uint64_t backlog_bytes = kLogTailBacklogBytes)
      : path_(std::move(path)), backlog_bytes_(backlog_bytes) {}

  const std::string& path() const { return path_; }

  // The lines added since the last poll, without their line ends.
  std::vector<std::string> poll();

 private:
  std::string path_;
  std::uint64_t backlog_bytes_;
  bool started_ = false;
  bool skip_partial_ = false;  // drop text up to the first line end
  std::uint64_t offset_ = 0;
  std::string partial_;
};

}  // namespace gamepilot
