#include "schedule.h"

#include <algorithm>
#include <cmath>

namespace gamepilot {

std::int64_t InputSchedule::frames(double ms) const {
  return std::llround(ms * frame_rate_ / 1000.0);
}

std::int64_t InputSchedule::submit(std::string batch_id,
                                   const std::vector<InputCommand>& commands,
                                   std::int64_t now_seq) {
  Batch batch;
  batch.id = std::move(batch_id);
  batch.start =
      batches_.empty() ? now_seq : std::max(now_seq, batches_.back().end);
  // Boundaries come from the running ms total so rounding does not drift;
  // `extra` keeps every press at least one frame long.
  double total_ms = 0;
  std::int64_t extra = 0;
  const auto boundary = [&] { return batch.start + frames(total_ms) + extra; };
  for (const InputCommand& command : commands) {
    if (command.is_wait) {
      total_ms += command.wait_ms;
      continue;
    }
    const std::int64_t from = boundary();
    total_ms += command.hold_ms;
    std::int64_t to = boundary();
    if (to <= from) {
      extra += from + 1 - to;
      to = from + 1;
    }
    batch.presses.push_back(Segment{from, to, command.buttons});
    total_ms += command.cooldown_ms;
  }
  batch.end = std::max(boundary(), batch.start);
  const std::int64_t start = batch.start;
  batches_.push_back(std::move(batch));
  return start;
}

KeyMask InputSchedule::mask_at(std::int64_t seq) const {
  for (const Batch& batch : batches_) {
    if (seq < batch.start || seq >= batch.end) {
      continue;
    }
    for (const Segment& press : batch.presses) {
      if (seq >= press.from && seq < press.to) {
        return press.mask;
      }
    }
    return 0;
  }
  return 0;
}

std::vector<FinishedBatch> InputSchedule::take_finished(std::int64_t seq) {
  std::vector<FinishedBatch> finished;
  while (!batches_.empty() && batches_.front().end <= seq) {
    finished.push_back(
        FinishedBatch{batches_.front().id, batches_.front().end});
    batches_.erase(batches_.begin());
  }
  return finished;
}

}  // namespace gamepilot
