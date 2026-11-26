// The Switch's GBA picture sits where nso_gba_viewport() says on every FRLG
// capture of the lab's (src/games/pokemon/frlg/readers/test/images/switch),
// and the check refuses frames it does not fit: a capture of another game and
// the picture shifted by a few game pixels.

#include "switch_geometry.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <string>
#include <vector>

#include "check.h"

using namespace gamepilot;

namespace {

const std::string kDir = GAMEPILOT_SWITCH_CAPTURES_DIR;

// The FRLG captures (pc-deposit-20261102/pc6_n.png is a BDSP frame).
const std::vector<std::string> kFrlgCaptures = {
    "pc-deposit-20261102/pc10_b2.png",
    "pc-deposit-20261102/pc6_box.png",
    "pc-deposit-20261102/pc7_sub.png",
    "pc-deposit-20261102/pr6_start.png",
    "pc-deposit-20261102/sv3_start.png",
    "pc-deposit-20261102/sv4_q1.png",
    "summary-20261102/sm3_party.png",
    "summary-20261102/sm3_s1.png",
    "summary-20261102/sm3_s2.png",
    "summary-20261102/sm3_s3.png",
    "summary-20261102/sm3_s3a.png",
    "summary-20261102/sm3_sub.png",
    "tmcase/01-bag-items.png",
    "tmcase/02-bag-key-items.png",
    "tmcase/03-key-items-tmcase-selected.png",
    "tmcase/04-tmcase-after-A.png",
    "tmcase/05-tmcase-list.png",
    "tmcase/07-tm-use-party.png",
    "tmcase/12-forget-move-list.png",
    "tmcase/16-summary-moves-after-teach.png",
    // A small room, black all round it (bring-up at mg-06's end).
    "console-b-20261124/dark-room-dept-store.png",
};

// The picture is 1560 x 1040 at (180, 5) of a 1080p frame: 6.5 frame pixels
// per game pixel.
void check_viewport_pixels() {
  const Viewport viewport = nso_gba_viewport();
  const cv::Rect picture = box_to_pixels(viewport.picture, 1920, 1080);
  CHECK(picture == cv::Rect(180, 5, 1560, 1040));
  CHECK(viewport.game_width == 240 && viewport.game_height == 160);
}

void check_frlg_captures() {
  const Box picture = nso_gba_viewport().picture;
  for (const std::string& name : kFrlgCaptures) {
    const cv::Mat frame = cv::imread(kDir + "/" + name);
    CHECK(frame.cols == 1920 && frame.rows == 1080);
    const GeometryCheck check = check_geometry(frame, picture);
    if (!check.ok) {
      std::fprintf(stderr, "%s: %s\n", name.c_str(), describe(check).c_str());
    }
    CHECK(check.ok);
  }
}

void check_wrong_geometry() {
  const Box picture = nso_gba_viewport().picture;
  // A BDSP frame fills the whole frame.
  const cv::Mat bdsp = cv::imread(kDir + "/pc-deposit-20261102/pc6_n.png");
  CHECK(!check_geometry(bdsp, picture).ok);
  // The FRLG picture moved 3 game pixels (20 frame pixels) right.
  const cv::Mat frame = cv::imread(kDir + "/tmcase/01-bag-items.png");
  cv::Mat shifted = cv::Mat::zeros(frame.size(), frame.type());
  frame(cv::Rect(0, 0, 1900, 1080))
      .copyTo(shifted(cv::Rect(20, 0, 1900, 1080)));
  CHECK(!check_geometry(shifted, picture).ok);
  // The picture shrunk to 40% inside the box: mostly dark, refused.
  const cv::Rect box = box_to_pixels(picture, 1920, 1080);
  cv::Mat small;
  cv::resize(frame(box), small, cv::Size(), 0.4, 0.4);
  cv::Mat shrunk = cv::Mat::zeros(frame.size(), frame.type());
  small.copyTo(shrunk(cv::Rect(box.x + (box.width - small.cols) / 2,
                               box.y + (box.height - small.rows) / 2,
                               small.cols, small.rows)));
  CHECK(!check_geometry(shrunk, picture).ok);
  // Nothing on screen.
  CHECK(!check_geometry(cv::Mat::zeros(frame.size(), frame.type()), picture)
             .ok);
}

// A saved frame reads back pixel for pixel: the file is the PNG's bytes, with
// no text-file BOM or line-ending changes (#72's --capture-check wrote both).
void check_save_png_round_trip() {
  cv::Mat frame(64, 64, CV_8UC3);
  cv::randu(frame, cv::Scalar::all(0), cv::Scalar::all(255));
  const std::string path = std::string(GAMEPILOT_TEST_OUTPUT_DIR) + "/save_png_test.png";
  save_png(path, frame);
  const cv::Mat read = cv::imread(path, cv::IMREAD_COLOR);
  CHECK(!read.empty() && read.size() == frame.size() &&
        cv::norm(read, frame, cv::NORM_INF) == 0);
}

}  // namespace

int main() {
  check_save_png_round_trip();
  check_viewport_pixels();
  check_frlg_captures();
  check_wrong_geometry();
  return TEST_RESULT();
}
