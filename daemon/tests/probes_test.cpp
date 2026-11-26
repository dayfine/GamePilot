// The probe kinds on synthetic frames, the viewport mapping (the GBA picture
// in the Switch frame, and a full-screen native Switch game), base64 decoding,
// and the input schedule's frame rounding.

#include "probes.h"

#include <cmath>
#include <cstdint>
#include <opencv2/imgcodecs.hpp>
#include <optional>
#include <string>
#include <vector>

#include "base64.h"
#include "check.h"
#include "probe_evaluation.h"
#include "schedule.h"
#include "template_store.h"

using namespace gamepilot;

namespace {

bool near(double a, double b) { return std::abs(a - b) < 1e-6; }

// The pixel rectangle of a frame-normalized box in a 240x160 frame.
cv::Rect gba_pixels(const Box& box) { return box_to_pixels(box, 240, 160); }

void check_color_stats() {
  // A 240x160 BGR frame: black, with a pure red block in the right half of the
  // top rows.
  cv::Mat frame(160, 240, CV_8UC3, cv::Scalar(0, 0, 0));
  frame(cv::Rect(120, 0, 120, 16)).setTo(cv::Scalar(0, 0, 255));

  const ColorStats inside =
      color_stats(frame, gba_pixels(Box{0.5, 0.0, 0.5, 0.1}));
  CHECK(near(inside.mean[0], 255) && near(inside.mean[1], 0) &&
        near(inside.mean[2], 0));
  CHECK(near(inside.stddev[0], 0));

  // Left half of the box red, right half black: mean 127.5, stddev 127.5 in
  // red.
  const ColorStats half =
      color_stats(frame, gba_pixels(Box{0.25, 0.0, 0.5, 0.1}));
  CHECK(near(half.mean[0], 127.5) && near(half.stddev[0], 127.5));
  CHECK(near(half.mean[2], 0));

  CHECK(gba_pixels(Box{0.7, 0.02, 0.28, 0.5}) == cv::Rect(168, 3, 67, 80));
  // A box thinner than a pixel still covers one.
  CHECK(gba_pixels(Box{0.999, 0.999, 0.0001, 0.0001}).area() == 1);
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

  const cv::Rect right_top = gba_pixels(Box{0.5, 0.0, 0.5, 0.25});
  const TemplateMatch exact = template_match(frame, pattern, right_top);
  CHECK(near(exact.score, 0));
  CHECK(near(exact.x, 200) && near(exact.y, 20));

  // A box that misses the pattern: the best placement is all gray, so the
  // score is the pattern's mean squared distance from gray (128). Per row of
  // 4 pixels: white is 127 off in 3 channels, red 128, 128 and 127, black 128
  // in 3.
  const TemplateMatch miss =
      template_match(frame, pattern, gba_pixels(Box{0.0, 0.5, 0.5, 0.5}));
  const double off127 = 127.0 * 127.0;
  const double off128 = 128.0 * 128.0;
  const double expected = 4 *
                          (3 * off127 + (2 * off128 + off127) + 3 * off128) /
                          (12.0 * 3) / (255.0 * 255.0);
  CHECK(std::abs(miss.score - expected) < 1e-4);
  CHECK(miss.x >= 0 && miss.y >= 80);

  // A flat black template matches black exactly; TM_SQDIFF_NORMED would say 1.
  const cv::Mat black(3, 3, CV_8UC3, cv::Scalar(0, 0, 0));
  frame(cv::Rect(0, 0, 10, 10)).setTo(cv::Scalar(0, 0, 0));
  CHECK(near(
      template_match(frame, black, gba_pixels(Box{0.0, 0.0, 0.25, 0.25})).score,
      0));
  CHECK(is_known_probe_kind("core.template_match@1"));
}

void check_mask_match() {
  // Dark gray text on yellow, and the same word drawn blue on white: the ink
  // masks agree, so the mask score is 0 where the color score is not.
  const ColorRange dark_ink{{0, 0, 0}, {144, 144, 255}};
  cv::Mat frame(20, 40, CV_8UC3, cv::Scalar(198, 255, 255));
  frame(cv::Rect(10, 5, 2, 6)).setTo(cv::Scalar(99, 99, 99));
  frame(cv::Rect(14, 5, 3, 1)).setTo(cv::Scalar(99, 99, 99));
  cv::Mat word(8, 10, CV_8UC3, cv::Scalar(255, 255, 255));
  word(cv::Rect(2, 1, 2, 6)).setTo(cv::Scalar(240, 88, 40));
  word(cv::Rect(6, 1, 3, 1)).setTo(cv::Scalar(240, 88, 40));
  const cv::Rect whole(0, 0, 40, 20);
  const cv::Mat word_mask = ink_mask(word, dark_ink);
  CHECK(cv::countNonZero(word_mask) == 15);
  const TemplateMatch masked = mask_match(frame, word_mask, whole, dark_ink);
  CHECK(near(masked.score, 0) && near(masked.x, 8) && near(masked.y, 4));
  CHECK(template_match(frame, word, whole).score > 0.03);

  // One stroke pixel missing: 1 of the template's 80 pixels differs.
  frame.at<cv::Vec3b>(10, 11) = cv::Vec3b(198, 255, 255);
  CHECK(near(mask_match(frame, word_mask, whole, dark_ink).score, 1.0 / 80));
}

void check_skip_seams() {
  // A scaled mask's row: blank, a seam (half each game pixel), two ink pixels.
  // The box's binary mask agrees with every whole pixel; the seam alone costs
  // 128^2 / 255^2 of a pixel, unless it is left out.
  cv::Mat template_mask(1, 4, CV_8UC1, cv::Scalar(255));
  template_mask.at<std::uint8_t>(0, 0) = 0;
  template_mask.at<std::uint8_t>(0, 1) = 128;
  const cv::Mat whole = whole_pixels(template_mask);
  CHECK(whole.type() == CV_8UC1 && cv::countNonZero(whole) == 3 &&
        whole.at<std::uint8_t>(0, 1) == 0 && whole.at<std::uint8_t>(0, 2) == 1);
  const ColorRange dark{{0, 0, 0}, {90, 90, 90}};
  cv::Mat frame(1, 6, CV_8UC3, cv::Scalar(255, 255, 255));
  frame(cv::Rect(3, 0, 3, 1)).setTo(cv::Scalar(57, 57, 57));
  const cv::Rect box(1, 0, 4, 1);
  const double seam = 128.0 * 128 / (255.0 * 255);
  CHECK(near(mask_match(frame, template_mask, box, dark).score, seam / 4));
  const TemplateMatch skipped =
      mask_match(frame, template_mask, box, dark, whole);
  CHECK(near(skipped.score, 0) && near(skipped.x, 1));

  // A whole pixel that differs still counts, over the 3 compared.
  frame.at<cv::Vec3b>(0, 4) = cv::Vec3b(255, 255, 255);
  CHECK(
      near(mask_match(frame, template_mask, box, dark, whole).score, 1.0 / 3));
}

void check_color_count() {
  // A 10x10 frame: gray, with 5 pixels of dark red (200, 40, 30) and 5 of
  // bright red (250, 60, 50) in the top row.
  cv::Mat frame(10, 10, CV_8UC3, cv::Scalar(128, 128, 128));
  frame(cv::Rect(0, 0, 5, 1)).setTo(cv::Scalar(30, 40, 200));
  frame(cv::Rect(5, 0, 5, 1)).setTo(cv::Scalar(50, 60, 250));
  const cv::Rect whole(0, 0, 10, 10);

  const ColorCount reds =
      color_count(frame, whole, ColorRange{{160, 0, 0}, {255, 120, 120}});
  CHECK(near(reds.fraction, 0.1));
  CHECK(reds.mean && near((*reds.mean)[0], 225) && near((*reds.mean)[1], 50) &&
        near((*reds.mean)[2], 40));

  // The range is inclusive at both ends: exactly the bright red.
  const ColorCount bright =
      color_count(frame, whole, ColorRange{{250, 60, 50}, {250, 60, 50}});
  CHECK(near(bright.fraction, 0.05));
  CHECK(bright.mean && near((*bright.mean)[0], 250));

  const ColorCount none =
      color_count(frame, whole, ColorRange{{0, 200, 0}, {255, 255, 255}});
  CHECK(near(none.fraction, 0) && !none.mean);
  CHECK(is_known_probe_kind("core.color_count@1"));
}

void check_viewport() {
  // A 1920x1080 capture with the 240x160 picture inside side bars, as the
  // Switch's GBA app shows it.
  const Viewport switch_capture = nso_gba_viewport();
  const Box whole = picture_box_to_frame(switch_capture, Box{0, 0, 1, 1});
  CHECK(box_to_pixels(whole, 1920, 1080) == cv::Rect(180, 5, 1560, 1040));
  const Box right_half =
      picture_box_to_frame(switch_capture, Box{0.5, 0, 0.5, 1});
  CHECK(box_to_pixels(right_half, 1920, 1080) == cv::Rect(960, 5, 780, 1040));
  CHECK(near(frame_x_to_picture(switch_capture, 960.0 / 1920), 0.5));
  CHECK(near(frame_y_to_picture(switch_capture, 5.0 / 1080), 0));

  // 6.5 frame pixels per game pixel each way.
  CHECK(template_size_in_frame(switch_capture, cv::Size(4, 2), 1920, 1080) ==
        cv::Size(26, 13));
  const Viewport mgba{Box{0, 0, 1, 1}, 240, 160};
  CHECK(template_size_in_frame(mgba, cv::Size(4, 2), 240, 160) ==
        cv::Size(4, 2));

  // INTER_AREA: at a whole scale every game pixel becomes a block.
  cv::Mat pattern(1, 2, CV_8UC3, cv::Scalar(0, 0, 0));
  pattern.at<cv::Vec3b>(0, 1) = cv::Vec3b(255, 255, 255);
  const cv::Mat doubled = scale_template(pattern, cv::Size(4, 2));
  CHECK(doubled.at<cv::Vec3b>(1, 1) == cv::Vec3b(0, 0, 0));
  CHECK(doubled.at<cv::Vec3b>(1, 2) == cv::Vec3b(255, 255, 255));

  CHECK(parse_box("0.09375,0.00462963,0.8125,0.962963").has_value());
  CHECK(!parse_box("0.5,0,0.6,1"));  // past the right edge
  CHECK(!parse_box("0,0,1"));
  CHECK(!parse_box("0,0,1,1,"));
}

// A --viewport value, as the daemon and probe_images take it: a name is the
// whole viewport, x,y,w,h moves the base's picture and keeps its game size.
void check_parse_viewport() {
  const Viewport base{Box{0, 0, 1, 1}, 240, 160};
  const std::optional<Viewport> native = parse_viewport("native", base);
  CHECK(native && native->game_width == 1920 && native->game_height == 1080 &&
        native->picture.w == 1);
  const std::optional<Viewport> gba = parse_viewport("nso-gba", base);
  CHECK(gba && gba->picture.x == nso_gba_viewport().picture.x);
  const std::optional<Viewport> moved = parse_viewport("0.125,0,0.75,1", base);
  CHECK(moved && moved->picture.x == 0.125 && moved->picture.w == 0.75 &&
        moved->game_width == 240 && moved->game_height == 160);
  CHECK(!parse_viewport("gba", base));
  CHECK(!parse_viewport("0.5,0,0.6,1", base));
  CHECK(!parse_viewport("", base));
}

// A full-screen Switch game: boxes are fractions of the whole 1920x1080
// frame (the fork's ImageFloatBox) and templates are 1080p crops, matched at
// their own size.
void check_native_viewport() {
  const Viewport native = native_switch_viewport();
  CHECK(box_to_pixels(picture_box_to_frame(native, Box{0, 0, 1, 1}), 1920,
                      1080) == cv::Rect(0, 0, 1920, 1080));
  CHECK(template_size_in_frame(native, cv::Size(60, 40), 1920, 1080) ==
        cv::Size(60, 40));
  CHECK(named_viewport("native").has_value() &&
        named_viewport("native")->game_width == 1920 &&
        named_viewport("native")->game_height == 1080);
  CHECK(named_viewport("nso-gba").has_value() &&
        named_viewport("nso-gba")->game_width == 240);
  CHECK(!named_viewport("gba"));

  // A gray 1920x1080 frame: a 60x40 striped pattern at pixel (1500, 900) and
  // a red 192x108 block in the top-left corner.
  cv::Mat frame(1080, 1920, CV_8UC3, cv::Scalar(128, 128, 128));
  cv::Mat pattern(40, 60, CV_8UC3, cv::Scalar(255, 255, 255));
  pattern.rowRange(10, 20).setTo(cv::Scalar(0, 0, 255));
  pattern.rowRange(20, 30).setTo(cv::Scalar(0, 0, 0));
  pattern.copyTo(frame(cv::Rect(1500, 900, 60, 40)));
  frame(cv::Rect(0, 0, 192, 108)).setTo(cv::Scalar(0, 0, 255));

  TemplateStore templates;
  std::vector<uchar> png;
  cv::imencode(".png", pattern, png);
  const auto hash = templates.add_png(std::string(png.begin(), png.end()));
  CHECK(hash.has_value());
  if (!hash) {
    return;
  }
  ProbeSpec match{.id = "corner",
                  .kind = std::string(kTemplateMatchKind),
                  .box = Box{0.75, 0.8, 0.2, 0.15},
                  .template_hash = *hash};
  const FrameProbe mapped = map_probe(match, templates, native, 1920, 1080);
  CHECK(mapped.pixels == cv::Rect(1440, 864, 384, 162));
  CHECK(mapped.template_image.size() == cv::Size(60, 40));
  const ProbeResult matched = evaluate_probe(mapped, frame);
  const auto* found = std::get_if<TemplateMatch>(&matched);
  CHECK(found != nullptr && near(found->score, 0) &&
        near(found->x, 1500.0 / 1920) && near(found->y, 900.0 / 1080));

  // The GBA viewport would scale the same template 6.5 times, past its box.
  bool too_big = false;
  try {
    map_probe(match, templates, nso_gba_viewport(), 1920, 1080);
  } catch (const RpcError& error) {
    too_big = error.code() == kInvalidParams;
  }
  CHECK(too_big);

  ProbeSpec red{.id = "red",
                .kind = std::string(kColorCountKind),
                .box = Box{0, 0, 0.2, 0.2},
                .color_range = ColorRange{{200, 0, 0}, {255, 60, 60}}};
  const FrameProbe red_mapped = map_probe(red, templates, native, 1920, 1080);
  CHECK(red_mapped.pixels == cv::Rect(0, 0, 384, 216));
  const ProbeResult counted = evaluate_probe(red_mapped, frame);
  const auto* count = std::get_if<ColorCount>(&counted);
  CHECK(count != nullptr && near(count->fraction, 0.25));
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
  InputCommand start;
  start.buttons = 8;
  start.hold_ms = 100;
  start.cooldown_ms = 100;
  InputCommand wait;
  wait.wait_ms = 250;
  wait.is_wait = true;
  CHECK(schedule.submit("b1", {start, wait}, 1203) == 1203);
  CHECK(schedule.mask_at(1202) == 0);
  CHECK(schedule.mask_at(1203) == 8);
  CHECK(schedule.mask_at(1208) == 8);
  CHECK(schedule.mask_at(1209) == 0);
  // A second batch queues after the first one ends (frame 1230).
  InputCommand b;
  b.buttons = 2;  // GBA B, 0 ms
  CHECK(schedule.submit("b2", {b}, 1205) == 1230);
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
  check_mask_match();
  check_skip_seams();
  check_color_count();
  check_viewport();
  check_native_viewport();
  check_parse_viewport();
  check_base64();
  check_schedule();
  return TEST_RESULT();
}
