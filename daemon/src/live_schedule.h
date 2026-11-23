// Submitted command batches in wall time, for a live backend: each press and
// wait becomes a timed key segment that the server hands to the controller
// when its start time comes. Batches run one after another, as in
// InputSchedule (schedule.h), but nothing is rounded to frames: the device
// times each segment itself.

#pragma once

#include <deque>
#include <optional>
#include <string>
#include <vector>

#include "backend.h"
#include "schedule.h"

namespace gamepilot {

struct KeySegment {
  double start_ms = 0;  // daemon clock
  double ms = 0;        // how long `keys` are held
  KeyMask keys = 0;
};

struct EndedBatch {
  std::string batch_id;
  double end_ms = 0;
};

class LiveSchedule {
 public:
  // Queues a batch after the queued ones (or at `now_ms` when idle); returns
  // its start time.
  double submit(std::string batch_id, const std::vector<InputCommand>& commands,
                double now_ms);

  // Removes and returns, in order, the segments that start at or before
  // `now_ms`.
  std::vector<KeySegment> take_due(double now_ms);

  // Removes and returns, in order, the batches that ended at or before
  // `now_ms`.
  std::vector<EndedBatch> take_finished(double now_ms);

  // The next segment start or batch end, if any.
  std::optional<double> next_event_ms() const;

  void clear();

 private:
  std::deque<KeySegment> segments_;
  std::deque<EndedBatch> batches_;
  double end_ms_ = 0;  // when the last queued batch ends
};

}  // namespace gamepilot
