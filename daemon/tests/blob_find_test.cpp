// core.find@1 and core.line_shares@1: on synthetic frames, and on PLZA console
// frames from CommandLineTests (PokemonLZA/AutoStoryDetectors/ArrivalToAd at
// ee10083, copied under src/games/pokemon/plza/readers/test/images/switch). The real
// frames check that the probes' numbers give back what the fork's detectors
// compute on the same pixels: PixelShares' share_of over a box slid row by
// row or column by column, and AdvanceArrowDetector's blob tests
// (PokemonLZA_StoryDialogDetector.cpp).

#include "blob_find.h"

#include <cmath>
#include <cstdlib>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <string>
#include <vector>

#include "check.h"
#include "probes.h"

using namespace gamepilot;

namespace {

bool near(double a, double b, double tolerance = 1e-9) {
  return std::abs(a - b) <= tolerance;
}

const cv::Vec3b kRed(0, 0, 255);  // BGR

PixelTest red_test() {
  return {
      ChannelComparison{{1, 0, 0}, ChannelComparison::Op::kGreaterEqual, 200},
      ChannelComparison{{1, -1, 0}, ChannelComparison::Op::kGreater, 150}};
}

void check_passes() {
  using Op = ChannelComparison::Op;
  // b > r + 60 as -r + b > 60, on both sides of the edge.
  const PixelTest sky{ChannelComparison{{-1, 0, 1}, Op::kGreater, 60}};
  CHECK(passes(sky, 100, 0, 161));
  CHECK(!passes(sky, 100, 0, 160));
  const PixelTest at_least{
      ChannelComparison{{0, -1, 1}, Op::kGreaterEqual, -20}};  // b + 20 >= g
  CHECK(passes(at_least, 0, 120, 100));
  CHECK(!passes(at_least, 0, 121, 100));
  const PixelTest below{ChannelComparison{{1, 1, 1}, Op::kLess, 30},
                        ChannelComparison{{1, 0, 0}, Op::kLessEqual, 10}};
  CHECK(passes(below, 10, 10, 9));
  CHECK(!passes(below, 11, 0, 0));
  CHECK(!passes(below, 10, 10, 10));
  CHECK(passes(PixelTest{}, 0, 0, 0));
}

void check_line_shares() {
  // 8x4: red in the left half of the top two rows.
  cv::Mat frame(4, 8, CV_8UC3, cv::Scalar(0, 0, 0));
  frame(cv::Rect(0, 0, 4, 2)).setTo(cv::Scalar(0, 0, 255));
  const LineShares shares =
      line_shares(frame, cv::Rect(0, 0, 8, 4), red_test());
  CHECK(shares.rows == (std::vector<double>{0.5, 0.5, 0, 0}));
  CHECK(shares.columns ==
        (std::vector<double>{0.5, 0.5, 0.5, 0.5, 0, 0, 0, 0}));
  const LineShares part = line_shares(frame, cv::Rect(2, 1, 4, 2), red_test());
  CHECK(part.rows == (std::vector<double>{0.5, 0}));
  CHECK(part.columns == (std::vector<double>{0.5, 0.5, 0, 0}));
}

FrameFind red_find() {
  FindSpec spec;
  spec.filters.push_back(ColorRange{{200, 0, 0}, {255, 50, 50}});
  spec.min_area = 2;
  spec.margin = 2;
  return map_find(spec, 1, 1, cv::Mat(), cv::Mat());
}

void check_find() {
  // 20x10: a 4x3 block, a 3-pixel diagonal (three blobs, 4-connected), a
  // 2x1 bar one pixel right of the block, and a lone pixel.
  cv::Mat frame(10, 20, CV_8UC3, cv::Scalar(0, 0, 0));
  frame(cv::Rect(2, 2, 4, 3)).setTo(cv::Scalar(0, 0, 255));
  frame(cv::Rect(7, 3, 2, 1)).setTo(cv::Scalar(0, 0, 255));
  for (int i = 0; i < 3; i++) {
    frame.at<cv::Vec3b>(6 + i, 12 + i) = kRed;
  }
  frame.at<cv::Vec3b>(0, 19) = kRed;
  const FindResult found =
      find_blobs(frame, cv::Rect(0, 0, 20, 10), red_find());
  // min_area 2: the block and the bar; the diagonal's and the lone pixels
  // are blobs of one.
  CHECK(found.blobs.size() == 2);
  if (found.blobs.size() == 2) {
    const Blob& block = found.blobs[0];
    CHECK(block.box == cv::Rect(2, 2, 4, 3) && block.area == 12);
    // Within 2 pixels of the block: the bar's first pixel, (7, 3).
    CHECK(block.stray && near(*block.stray, 1.0 / 12));
    const Blob& bar = found.blobs[1];
    CHECK(bar.box == cv::Rect(7, 3, 2, 1) && bar.area == 2);
    // The block's column x 5, rows 2..4.
    CHECK(bar.stray && near(*bar.stray, 3.0 / 2));
    CHECK(!bar.score && !bar.overlap);
  }

  // Inside a box: the box's own pixels only, reported in frame pixels.
  const FindResult boxed =
      find_blobs(frame, cv::Rect(6, 0, 14, 10), red_find());
  CHECK(boxed.blobs.size() == 1 && boxed.blobs[0].box == cv::Rect(7, 3, 2, 1));
  // Stray is counted inside the box only: the block lies outside it.
  CHECK(boxed.blobs.size() == 1 && near(*boxed.blobs[0].stray, 0));

  // Size filter, in game pixels: at 2 frame pixels per game pixel the block
  // is 2 x 1.5 game pixels, the bar 1 x 0.5.
  FindSpec sized;
  sized.filters.push_back(ColorRange{{200, 0, 0}, {255, 50, 50}});
  sized.min_area = 0.5;  // 2 frame pixels at 2 x 2
  sized.min_size = std::array<double, 2>{1.5, 1};
  const FrameFind scaled = map_find(sized, 2, 2, cv::Mat(), cv::Mat());
  CHECK(scaled.min_area == 2);
  const FindResult big = find_blobs(frame, cv::Rect(0, 0, 20, 10), scaled);
  CHECK(big.blobs.size() == 1 && big.blobs[0].area == 12);
  sized.max_size = std::array<double, 2>{1.9, 2};
  const FindResult none =
      find_blobs(frame, cv::Rect(0, 0, 20, 10),
                 map_find(sized, 2, 2, cv::Mat(), cv::Mat()));
  CHECK(none.blobs.empty());
}

// A BGRA template from a BGR image, alpha 255, with `clear` transparent.
cv::Mat with_alpha(const cv::Mat& bgr, const cv::Rect& clear) {
  cv::Mat bgra;
  cv::cvtColor(bgr, bgra, cv::COLOR_BGR2BGRA);
  bgra(clear).setTo(cv::Scalar(0, 0, 0, 0));
  return bgra;
}

void check_template_rmsd() {
  cv::Mat drawn(4, 4, CV_8UC3, cv::Scalar(40, 80, 120));
  drawn(cv::Rect(0, 0, 2, 2)).setTo(cv::Scalar(200, 100, 50));
  const cv::Mat opaque = with_alpha(drawn, cv::Rect(0, 0, 0, 0));
  CHECK(near(template_rmsd(drawn, opaque), 0));
  // Twice the size: nearest neighbour gives the same pixels back.
  cv::Mat doubled;
  cv::resize(drawn, doubled, cv::Size(8, 8), 0, 0, cv::INTER_NEAREST);
  CHECK(near(template_rmsd(doubled, opaque), 0));
  // 10% brighter: the template's colours scale by the same ratio, so only
  // rounding is left.
  cv::Mat brighter;
  drawn.convertTo(brighter, -1, 1.1);
  CHECK(template_rmsd(brighter, opaque) < 1);
  // 30% brighter: the ratio stops at 1.15. Channel 120 -> 156 seen, 138
  // drawn; the others likewise; computed below per pixel.
  cv::Mat much;
  drawn.convertTo(much, -1, 1.3);
  double sum = 0;
  for (int y = 0; y < 4; y++) {
    for (int x = 0; x < 4; x++) {
      for (int c = 0; c < 3; c++) {
        const int seen = much.at<cv::Vec3b>(y, x)[c];
        const int reference = std::min(
            static_cast<int>(static_cast<float>(drawn.at<cv::Vec3b>(y, x)[c]) *
                                 1.15F +
                             0.5F),
            255);
        sum += (reference - seen) * (reference - seen);
      }
    }
  }
  CHECK(near(template_rmsd(much, opaque), std::sqrt(sum / 16), 1e-9));
  // Transparent pixels count for nothing: paint them anything.
  const cv::Mat holed = with_alpha(drawn, cv::Rect(0, 0, 2, 2));
  cv::Mat painted = drawn.clone();
  painted(cv::Rect(0, 0, 2, 2)).setTo(cv::Scalar(0, 255, 0));
  CHECK(near(template_rmsd(painted, holed), 0));
}

void check_shape_overlap() {
  cv::Mat shape(4, 4, CV_8UC1, cv::Scalar(0));
  shape(cv::Rect(0, 0, 2, 4)).setTo(255);  // the left half
  cv::Mat blob(2, 2, CV_8UC1, cv::Scalar(0));
  blob.at<std::uint8_t>(0, 0) = 1;
  blob.at<std::uint8_t>(1, 0) = 1;
  CHECK(near(shape_overlap(blob, shape), 1));
  blob.at<std::uint8_t>(0, 1) = 1;  // one pixel outside: 2 of 3
  CHECK(near(shape_overlap(blob, shape), 2.0 / 3));
}

std::string plza_frame(const char* name) {
  return std::string(GAMEPILOT_PLZA_IMAGES_DIR) + "/arrival-to-ad/" + name;
}

// PixelShares::share_of for one box of the frame.
template <typename Test>
double share_of(const cv::Mat& frame, const cv::Rect& box, Test test) {
  int count = 0;
  for (int y = box.y; y < box.y + box.height; y++) {
    for (int x = box.x; x < box.x + box.width; x++) {
      const cv::Vec3b& p = frame.at<cv::Vec3b>(y, x);
      count += test(p[2], p[1], p[0]) ? 1 : 0;
    }
  }
  return static_cast<double>(count) / box.area();
}

// The mean of `shares` from `first`, `count` of them.
double mean_of(const std::vector<double>& shares, int first, int count) {
  double sum = 0;
  for (int i = first; i < first + count; i++) {
    sum += shares[static_cast<std::size_t>(i)];
  }
  return sum / count;
}

// ControlsHintDetector's card box (947, 872, 24, 28) slid from 60 px above to
// 20 below in steps of 2: one line_shares probe over the whole slide gives
// each position's sky blue share from its rows. On the platform the card
// shows (C++: 88%+).
void check_controls_hint_rows() {
  const cv::Mat frame = cv::imread(
      plza_frame("0001-platform-controls-hint.jpg"), cv::IMREAD_COLOR);
  CHECK(!frame.empty());
  if (frame.empty()) {
    return;
  }
  const auto sky = [](int r, int g, int b) {
    return b > 200 && g > 160 && b > r + 60;
  };
  using Op = ChannelComparison::Op;
  const PixelTest test{ChannelComparison{{0, 0, 1}, Op::kGreater, 200},
                       ChannelComparison{{0, 1, 0}, Op::kGreater, 160},
                       ChannelComparison{{-1, 0, 1}, Op::kGreater, 60}};
  const cv::Rect slide(947, 872 - 60, 24, 28 + 80);
  const LineShares shares = line_shares(frame, slide, test);
  double best = 0;
  for (int dy = -60; dy <= 20; dy += 2) {
    const double direct = share_of(frame, cv::Rect(947, 872 + dy, 24, 28), sky);
    const double from_rows = mean_of(shares.rows, dy + 60, 28);
    CHECK(near(direct, from_rows, 1e-12));
    best = std::max(best, from_rows);
  }
  CHECK(best >= 0.80);
}

// AutosaveDetector's icon box (1603, 73, 27, 31) slid up to 240 px right in
// steps of 4, by columns, for its white and dim cyan shares.
void check_autosave_columns() {
  const cv::Mat frame =
      cv::imread(plza_frame("0033-autosave-badge.jpg"), cv::IMREAD_COLOR);
  CHECK(!frame.empty());
  if (frame.empty()) {
    return;
  }
  using Op = ChannelComparison::Op;
  const PixelTest dim_cyan{
      ChannelComparison{{-1, 0, 1}, Op::kGreater, 40},
      ChannelComparison{{-1, 1, 0}, Op::kGreater, 25},
      ChannelComparison{{0, 0, 1}, Op::kGreater, 70},
      ChannelComparison{{0, -1, 1}, Op::kGreaterEqual, -20}};
  const auto dim_cyan_direct = [](int r, int g, int b) {
    return b > r + 40 && g > r + 25 && b > 70 && b + 20 >= g;
  };
  const cv::Rect slide(1603, 73, 27 + 240, 31);
  const LineShares shares = line_shares(frame, slide, dim_cyan);
  bool icon_seen = false;
  for (int dx = 0; dx <= 240; dx += 4) {
    const double direct =
        share_of(frame, cv::Rect(1603 + dx, 73, 27, 31), dim_cyan_direct);
    const double from_columns = mean_of(shares.columns, dx, 27);
    CHECK(near(direct, from_columns, 1e-12));
    icon_seen = icon_seen || from_columns >= 0.25;
  }
  CHECK(icon_seen);
}

// The V of AdvanceArrowDetector's v_match, drawn large (2560 x 1520) for
// core.find@1's shape: opaque where each arm runs from 10% in at the top to the
// middle at the bottom, 22% of the width across.
cv::Mat chevron_shape(int width, int height) {
  cv::Mat shape(height, width, CV_8UC4, cv::Scalar(0, 0, 0, 0));
  for (int y = 0; y < height; y++) {
    const double v = (y + 0.5) / height;
    for (int x = 0; x < width; x++) {
      const double u = (x + 0.5) / width;
      if (std::abs(std::abs(u - 0.5) - (0.40 * (1 - v) + 0.03)) <= 0.11) {
        shape.at<cv::Vec4b>(y, x) = cv::Vec4b(255, 255, 255, 255);
      }
    }
  }
  return shape;
}

// v_match as the C++ computes it on the blob's own pixels.
double v_match(const cv::Mat& blob) {
  int both = 0;
  int either = 0;
  for (int y = 0; y < blob.rows; y++) {
    const double v = (y + 0.5) / blob.rows;
    for (int x = 0; x < blob.cols; x++) {
      const double u = (x + 0.5) / blob.cols;
      const bool in_v =
          std::abs(std::abs(u - 0.5) - (0.40 * (1 - v) + 0.03)) <= 0.11;
      const bool in_blob = blob.at<std::uint8_t>(y, x) != 0;
      both += in_v && in_blob ? 1 : 0;
      either += in_v || in_blob ? 1 : 0;
    }
  }
  return either == 0 ? 0 : static_cast<double>(both) / either;
}

FrameFind chevron_find() {
  FindSpec spec;
  spec.filters.push_back(ColorRange{{235, 235, 220}, {255, 255, 255}});
  spec.filters.push_back(ColorRange{{0, 0, 0}, {110, 110, 110}});
  spec.min_area = 1;
  spec.min_size = std::array<double, 2>{26, 15};
  spec.max_size = std::array<double, 2>{40, 24};
  spec.margin = 4;
  constexpr int kShapeWidth = 2560;
  constexpr int kShapeHeight = 1520;
  return map_find(spec, 1, 1, cv::Mat(),
                  chevron_shape(kShapeWidth, kShapeHeight));
}

// The chevron at the box's bottom right on 0040 (dark, 32 x 20): the one blob
// of its size, its stray share and overlap within the C++'s limits (at most
// 0.09, at least 0.45), and the overlap the C++'s own v_match exactly: the
// shape is sampled at the blob's pixel centres, which differs from the formula
// only for a centre within half a shape pixel (1/5120 of the width) of the
// V's edge. On
// 0033 the only blob of that size is a scenery edge with strays.
void check_chevron() {
  const cv::Rect area(1370, 930, 110, 120);
  const cv::Mat frame = cv::imread(
      plza_frame("0040-text-box-advance-arrow.jpg"), cv::IMREAD_COLOR);
  CHECK(!frame.empty());
  if (frame.empty()) {
    return;
  }
  const FindResult found = find_blobs(frame, area, chevron_find());
  CHECK(found.blobs.size() == 1);
  if (found.blobs.size() == 1) {
    const Blob& chevron = found.blobs[0];
    CHECK(chevron.filter == 1 && chevron.box.width == 32 &&
          chevron.box.height == 20);
    CHECK(chevron.stray && *chevron.stray <= 0.09);
    CHECK(chevron.overlap && *chevron.overlap >= 0.45);
    // The blob's pixels again, for the C++'s v_match.
    cv::Mat mask;
    cv::inRange(frame(area), cv::Scalar(0, 0, 0), cv::Scalar(110, 110, 110),
                mask);
    cv::Mat labels;
    cv::connectedComponents(mask, labels, 4, CV_32S);
    const cv::Rect local = chevron.box - area.tl();
    const int label =
        labels.at<int>(local.y + local.height - 1, local.x + local.width / 2);
    cv::Mat own;
    cv::compare(labels(local), label, own, cv::CMP_EQ);
    CHECK(near(*chevron.overlap, v_match(own), 1e-9));
  }
  const cv::Mat autosave =
      cv::imread(plza_frame("0033-autosave-badge.jpg"), cv::IMREAD_COLOR);
  const FindResult other = find_blobs(autosave, area, chevron_find());
  for (const Blob& blob : other.blobs) {
    CHECK(blob.stray && *blob.stray > 0.09);
  }
}

}  // namespace

int main() {
  check_passes();
  check_line_shares();
  check_find();
  check_template_rmsd();
  check_shape_overlap();
  check_controls_hint_rows();
  check_autosave_columns();
  check_chevron();
  return TEST_RESULT();
}
