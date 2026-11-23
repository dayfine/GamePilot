// core.color_stats@1 and core.template_match@1 on synthetic frames, base64
// decoding, and the input schedule's frame rounding.

#include "probes.h"

#include <cmath>

#include "base64.h"
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

void check_template_match() {
  // A 240x160 gray frame with a 4x3 pattern (white, red, black stripes) at
  // pixel (200, 20).
  cv::Mat frame(160, 240, CV_8UC3, cv::Scalar(128, 128, 128));
  cv::Mat pattern(3, 4, CV_8UC3, cv::Scalar(255, 255, 255));
  pattern.row(1).setTo(cv::Scalar(0, 0, 255));
  pattern.row(2).setTo(cv::Scalar(0, 0, 0));
  pattern.copyTo(frame(cv::Rect(200, 20, 4, 3)));

  const Box right_top{0.5, 0.0, 0.5, 0.25};
  const TemplateMatch exact = template_match(frame, pattern, right_top);
  CHECK(near(exact.score, 0));
  CHECK(near(exact.x * 240, 200) && near(exact.y * 160, 20));

  // A box that misses the pattern: the best placement is all gray, so the
  // score is the pattern's mean squared distance from gray (128). Per row of
  // 4 pixels: white is 127 off in 3 channels, red 128, 128 and 127, black 128
  // in 3.
  const TemplateMatch miss =
      template_match(frame, pattern, Box{0.0, 0.5, 0.5, 0.5});
  const double off127 = 127.0 * 127.0;
  const double off128 = 128.0 * 128.0;
  const double expected = 4 *
                          (3 * off127 + (2 * off128 + off127) + 3 * off128) /
                          (12.0 * 3) / (255.0 * 255.0);
  CHECK(std::abs(miss.score - expected) < 1e-4);
  CHECK(miss.x >= 0 && miss.y >= 0.5);

  // A flat black template matches black exactly; TM_SQDIFF_NORMED would say 1.
  const cv::Mat black(3, 3, CV_8UC3, cv::Scalar(0, 0, 0));
  frame(cv::Rect(0, 0, 10, 10)).setTo(cv::Scalar(0, 0, 0));
  CHECK(near(template_match(frame, black, Box{0.0, 0.0, 0.25, 0.25}).score, 0));

  CHECK(template_fits_box(pattern, right_top, 240, 160));
  CHECK(!template_fits_box(pattern, Box{0.0, 0.0, 0.01, 0.01}, 240, 160));
  CHECK(is_known_probe_kind("core.template_match@1"));
}

void check_base64() {
  CHECK(decode_base64("") == std::string());
  CHECK(decode_base64("TWFu") == std::string("Man"));
  CHECK(decode_base64("TWE=") == std::string("Ma"));
  CHECK(decode_base64("TQ==") == std::string("M"));
  CHECK(decode_base64("/+8=") == std::string("\xff\xef"));
  CHECK(!decode_base64("TWF"));       // not a multiple of 4
  CHECK(!decode_base64("TW=u"));      // '=' inside
  CHECK(!decode_base64("TQ==TWFu"));  // padding before the end
  CHECK(!decode_base64("T!Fu"));
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
  check_template_match();
  check_base64();
  check_schedule();
  return TEST_RESULT();
}
