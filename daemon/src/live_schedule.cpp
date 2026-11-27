#include "live_schedule.h"

#include <algorithm>

namespace gamepilot {

double LiveSchedule::submit(std::string batch_id,
                            const std::vector<InputCommand>& commands,
                            double now_ms,
                            std::optional<double> start_at_t_ms) {
  double start = batches_.empty() ? now_ms : std::max(now_ms, end_ms_);
  if (start_at_t_ms) {
    start = std::max(start, *start_at_t_ms);
  }
  double t = start;
  const auto add = [&](KeyMask keys, const Sticks& sticks, double ms) {
    segments_.push_back(KeySegment{t, ms, keys, sticks});
    t += ms;
  };
  for (const InputCommand& command : commands) {
    if (command.is_wait) {
      add(0, Sticks{}, command.wait_ms);
      continue;
    }
    const Sticks tilted{command.left_stick.value_or(StickPosition{}),
                        command.right_stick.value_or(StickPosition{})};
    add(command.buttons, tilted, command.hold_ms);
    add(0, Sticks{}, command.cooldown_ms);
  }
  end_ms_ = t;
  batches_.push_back(EndedBatch{std::move(batch_id), t});
  return start;
}

std::vector<KeySegment> LiveSchedule::take_due(double now_ms) {
  std::vector<KeySegment> due;
  while (!segments_.empty() && segments_.front().start_ms <= now_ms) {
    due.push_back(segments_.front());
    segments_.pop_front();
  }
  return due;
}

std::vector<EndedBatch> LiveSchedule::take_finished(double now_ms) {
  std::vector<EndedBatch> ended;
  while (!batches_.empty() && batches_.front().end_ms <= now_ms) {
    ended.push_back(std::move(batches_.front()));
    batches_.pop_front();
  }
  return ended;
}

std::optional<double> LiveSchedule::next_event_ms() const {
  std::optional<double> next;
  if (!segments_.empty()) {
    next = segments_.front().start_ms;
  }
  if (!batches_.empty()) {
    next = std::min(next.value_or(batches_.front().end_ms),
                    batches_.front().end_ms);
  }
  return next;
}

void LiveSchedule::clear() {
  segments_.clear();
  batches_.clear();
}

}  // namespace gamepilot
