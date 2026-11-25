// Turns submitted command batches into key masks on exact frames. Batches run
// one after another; times in ms are rounded to whole frames at each command
// boundary.

#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include "backend.h"

namespace gamepilot {

struct InputCommand {
  // A press holds `buttons` for hold_ms, then releases for cooldown_ms.
  // A wait (buttons == 0, hold_ms == 0) holds nothing for wait_ms.
  KeyMask buttons = 0;
  double hold_ms = 0;
  double cooldown_ms = 0;
  double wait_ms = 0;
  bool is_wait = false;
  // The sticks a press tilts while it holds (the Switch only); one not given
  // is centred.
  std::optional<StickPosition> left_stick;
  std::optional<StickPosition> right_stick;
};

struct FinishedBatch {
  std::string batch_id;
  std::int64_t seq = 0;
};

class InputSchedule {
 public:
  explicit InputSchedule(double frame_rate) : frame_rate_(frame_rate) {}

  // Queues a batch after the queued ones (or at `now_seq` when idle); returns
  // its first frame.
  std::int64_t submit(std::string batch_id,
                      const std::vector<InputCommand>& commands,
                      std::int64_t now_seq);

  // Keys held during the frame that starts at `seq` (backend seq before the
  // step).
  KeyMask mask_at(std::int64_t seq) const;

  // Removes and returns, in order, the batches that ended at or before `seq`.
  std::vector<FinishedBatch> take_finished(std::int64_t seq);

  // Drops every queued batch.
  void clear() { batches_.clear(); }

  bool empty() const { return batches_.empty(); }

 private:
  struct Segment {
    std::int64_t from = 0;  // first frame
    std::int64_t to = 0;    // one past the last frame
    KeyMask mask = 0;
  };
  struct Batch {
    std::string id;
    std::int64_t start = 0;
    std::int64_t end = 0;
    std::vector<Segment> presses;
  };

  std::int64_t frames(double ms) const;

  double frame_rate_;
  std::vector<Batch> batches_;
};

}  // namespace gamepilot
