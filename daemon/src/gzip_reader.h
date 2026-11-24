// Reads a gzip file's decompressed bytes a chunk at a time (miniz, which
// CoreLib already builds): the hub reads a past run's wire.jsonl.gz, which
// the lab's disk cleanup leaves after a day, without unpacking it on disk.

#pragma once

#include <cstddef>
#include <memory>
#include <string>

namespace gamepilot {

class GzipReader {
 public:
  GzipReader();
  ~GzipReader();
  GzipReader(const GzipReader&) = delete;
  GzipReader& operator=(const GzipReader&) = delete;

  // False when the file does not open or is not gzip.
  bool open(const std::string& path);

  // Up to `size` decompressed bytes into `out`; 0 at the end or on a corrupt
  // stream.
  std::size_t read(char* out, std::size_t size);

 private:
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace gamepilot
