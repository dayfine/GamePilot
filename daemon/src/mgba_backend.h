// Backend for mGBA through the MgbaLink v1 bridge (lab/mgba/bridge.lua on the
// Arduino-Source agents branch): a TCP line protocol with
// GRANT/KEYS/FRAME/LOAD.

#pragma once

#include <cstdint>
#include <string>

#include "backend.h"
#include "net.h"

namespace gamepilot {

class MgbaBackend : public Backend {
 public:
  // Connects to the bridge on 127.0.0.1:port, says HELLO and holds the
  // emulator.
  explicit MgbaBackend(std::uint16_t port);
  ~MgbaBackend() override;

  const BackendInfo& info() const override { return info_; }
  std::int64_t seq() const override { return seq_; }
  void set_keys(KeyMask mask) override;
  std::int64_t step() override;
  cv::Mat frame() override;
  std::int64_t load_state(const std::string& path) override;
  std::int64_t save_state(const std::string& path) override;
  void release() override;

  // KEYS commands the bridge applied late (should stay 0 in lockstep).
  std::int64_t late_keys() const { return late_keys_; }

 private:
  std::string command(const std::string& line);
  std::int64_t grant(std::int64_t frame);

  Socket socket_;
  LineBuffer lines_;
  BackendInfo info_;
  std::int64_t seq_ = 0;
  std::int64_t late_keys_ = 0;
};

}  // namespace gamepilot
