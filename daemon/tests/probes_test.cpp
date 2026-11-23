// core.color_stats@1 on synthetic frames, and the input schedule's frame
// rounding.

#include "probes.h"

#include <cmath>

#include "check.h"
#include "schedule.h"

using namespace gamepilot;

namespace {

bool near(double a, double b) { return std::abs(a - b) < 1e-6; }

void check_color_stats() {
  // A 240x160 BGR frame: black, with a pure red block in the right half of the
  // top rows.
  cv::Mat frame(160, 240, CV_8UC3, cv::Scalar(0, 0, 0));
  frame(cv::Rect(120, 0, 120, 16)).setTo(cv::Scalar(0, 0, 255));

  const ColorStats inside = color_stats(frame, Box{0.5, 0.0, 0.5, 0.1});
  CHECK(near(inside.mean[0], 255) && near(inside.mean[1], 0) &&
        near(inside.mean[2], 0));
  CHECK(near(inside.stddev[0], 0));

  // Left half of the box red, right half black: mean 127.5, stddev 127.5 in
  // red.
  const ColorStats half = color_stats(frame, Box{0.25, 0.0, 0.5, 0.1});
  CHECK(near(half.mean[0], 127.5) && near(half.stddev[0], 127.5));
  CHECK(near(half.mean[2], 0));

  CHECK(box_to_pixels(Box{0.7, 0.02, 0.28, 0.5}, 240, 160) ==
        cv::Rect(168, 3, 67, 80));
  // A box thinner than a pixel still covers one.
  CHECK(box_to_pixels(Box{0.999, 0.999, 0.0001, 0.0001}, 240, 160).area() == 1);
  CHECK(is_known_probe_kind("core.color_stats@1"));
  CHECK(!is_known_probe_kind("core.ocr@1"));
}

void check_schedule() {
  InputSchedule schedule(59.7275);
  // The golden batch: Start 100 ms + 100 ms cooldown, then wait 250 ms.
  InputCommand start{8, 100, 100, 0, false};
  InputCommand wait{0, 0, 0, 250, true};
  CHECK(schedule.submit("b1", {start, wait}, 1203) == 1203);
  CHECK(schedule.mask_at(1202) == 0);
  CHECK(schedule.mask_at(1203) == 8);
  CHECK(schedule.mask_at(1208) == 8);
  CHECK(schedule.mask_at(1209) == 0);
  // A second batch queues after the first one ends (frame 1230).
  CHECK(schedule.submit("b2", {InputCommand{2, 0, 0, 0, false}}, 1205) == 1230);
  CHECK(schedule.mask_at(1230) == 2);  // a 0 ms press still lasts one frame
  CHECK(schedule.mask_at(1231) == 0);
  CHECK(schedule.take_finished(1229).empty());
  const auto done = schedule.take_finished(1231);
  CHECK(done.size() == 2 && done[0].batch_id == "b1" && done[0].seq == 1230);
  CHECK(done.size() == 2 && done[1].batch_id == "b2" && done[1].seq == 1231);
  CHECK(schedule.empty());
}

}  // namespace

int main() {
  check_color_stats();
  check_schedule();
  return TEST_RESULT();
}
