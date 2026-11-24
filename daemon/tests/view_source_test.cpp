// The view-only backend and its pieces: the server refuses every input method
// to it, the stale detector, the crop (a box, or the video area found), the
// window's visibility from the window list, and the log tail. Each table case
// is a name, the input and the expectation.

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <opencv2/imgproc.hpp>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "check.h"
#include "log_tail.h"
#include "net.h"
#include "rpc.h"
#include "server.h"
#include "view_backend.h"
#include "view_source.h"

using namespace gamepilot;
namespace pa = PokemonAutomation;

namespace {

// The same picture at `fps`, as a window that does not change.
class StillSource : public FrameSource {
 public:
  StillSource(cv::Mat picture, double fps) : picture_(picture), fps_(fps) {}
  bool read(cv::Mat& frame) override {
    std::this_thread::sleep_for(
        std::chrono::duration<double, std::milli>(1000 / fps_));
    frame = picture_.clone();
    return true;
  }
  double frame_rate() const override { return fps_; }

 private:
  cv::Mat picture_;
  double fps_;
};

// A window-like picture: flat grey UI with a noisy 16:9 video at `video`.
cv::Mat window_with_video(cv::Size size, cv::Rect video) {
  cv::Mat picture(size, CV_8UC3, cv::Scalar(60, 60, 60));
  cv::rectangle(picture, cv::Rect(10, 10, 80, 30), cv::Scalar(200, 200, 200),
                cv::FILLED);  // a button
  cv::Mat noise(video.size(), CV_8UC3);
  cv::randu(noise, cv::Scalar(100, 0, 0), cv::Scalar(255, 255, 255));
  noise.copyTo(picture(video));
  return picture;
}

// --- The server and a view backend ------------------------------------------

struct RefusalCase {
  std::string name;
  std::string request;  // one JSON-RPC line
  struct Expectation {
    bool refused = false;  // -32002 naming the method
  } expect;
};

const std::vector<RefusalCase> kRefusalCases = {
    {"submit is refused",
     R"({"jsonrpc":"2.0","id":1,"method":"submit","params":{"batch_id":"b","commands":[{"press":["A"],"hold_ms":50,"cooldown_ms":50}]}})",
     {.refused = true}},
    {"cancel is refused", R"({"jsonrpc":"2.0","id":2,"method":"cancel","params":{}})",
     {.refused = true}},
    {"load_state is refused",
     R"({"jsonrpc":"2.0","id":3,"method":"backend.load_state","params":{"path":"x.ss"}})",
     {.refused = true}},
    {"the lease is not granted",
     R"({"jsonrpc":"2.0","id":4,"method":"lease.acquire","params":{"owner":"pad"}})",
     {.refused = true}},
    {"hello is answered",
     R"({"jsonrpc":"2.0","id":5,"method":"hello","params":{"protocol":1,"client":"t"}})",
     {.refused = false}},
    {"status is answered", R"({"jsonrpc":"2.0","id":6,"method":"status"})",
     {.refused = false}},
    {"releasing no lease is answered",
     R"({"jsonrpc":"2.0","id":7,"method":"lease.release","params":{}})",
     {.refused = false}},
};

// Writes one request line and reads up to its reply, skipping notifications.
std::string call(Socket& socket, LineBuffer& lines, const std::string& line) {
  CHECK(socket.send_all(line + "\n"));
  for (int i = 0; i < 200; i++) {
    while (auto reply = lines.next_line()) {
      if (reply->find("\"id\"") != std::string::npos) {
        return *reply;
      }
    }
    if (poll_readable({&socket}, 10)[0]) {
      const auto data = socket.receive_some();
      if (!data) {
        break;
      }
      lines.append(*data);
    }
  }
  return "";
}

void check_server_refuses_input() {
  const Clock clock;
  ViewBackend backend(
      std::make_unique<StillSource>(cv::Mat(36, 64, CV_8UC3, cv::Scalar(9)),
                                    30),
      clock, ViewOptions{});
  CHECK(backend.info().kind == "view" && !backend.info().takes_input);
  ServerOptions options;
  options.port = 0;
  Server server(backend, options, clock);
  std::atomic<bool> stop{false};
  std::thread serving([&] { server.run(stop); });
  Socket socket = connect_local(server.port());
  LineBuffer lines;
  for (const RefusalCase& c : kRefusalCases) {
    const pa::JsonValue reply = parse_message(call(socket, lines, c.request));
    const pa::JsonObject* error = reply.to_object()->get_object("error");
    const bool refused =
        error != nullptr &&
        error->get_integer_default("code") == kBackendError &&
        error->get_string_default("message").find("view-only") !=
            std::string::npos;
    if (refused != c.expect.refused) {
      std::fprintf(stderr, "case: %s\n", c.name.c_str());
    }
    CHECK(refused == c.expect.refused);
  }
  stop.store(true);
  serving.join();
}

// --- The stale detector -------------------------------------------------------

struct StaleCase {
  std::string name;
  struct Input {
    std::vector<std::pair<std::uint64_t, double>> frames;  // fingerprint, ms
    double now_ms = 0;
  } input;
  struct Expectation {
    bool stale = false;
    double unchanged_ms = 0;
  } expect;
};

constexpr double kStaleAfterMs = 5000;

const std::vector<StaleCase> kStaleCases = {
    {"no frame yet is not stale", {{}, 9000}, {false, 0}},
    {"changing frames are live",
     {{{1, 0}, {2, 1000}, {3, 2000}}, 6000},
     {false, 4000}},
    {"the same picture for the limit is stale",
     {{{1, 0}, {1, 1000}, {1, 4000}}, 5000},
     {true, 5000}},
    {"frames that stop coming count as unchanged",
     {{{1, 0}, {2, 100}}, 5100},
     {true, 5000}},
    {"a change ends staleness",
     {{{1, 0}, {1, 6000}, {2, 6500}}, 7000},
     {false, 500}},
};

void check_stale_detector() {
  for (const StaleCase& c : kStaleCases) {
    StaleDetector detector(kStaleAfterMs);
    for (const auto& [fingerprint, ms] : c.input.frames) {
      detector.frame(fingerprint, ms);
    }
    const bool ok = detector.stale(c.input.now_ms) == c.expect.stale &&
                    detector.unchanged_ms(c.input.now_ms) ==
                        c.expect.unchanged_ms;
    if (!ok) {
      std::fprintf(stderr, "case: %s\n", c.name.c_str());
    }
    CHECK(ok);
  }
  const cv::Mat a(20, 30, CV_8UC3, cv::Scalar(1, 2, 3));
  cv::Mat b = a.clone();
  CHECK(frame_fingerprint(a) == frame_fingerprint(b));
  b.at<cv::Vec3b>(0, 0)[1] = 99;
  CHECK(frame_fingerprint(a) != frame_fingerprint(b));
}

// A still source goes stale through the backend too.
void check_backend_goes_stale() {
  const Clock clock;
  ViewBackend backend(
      std::make_unique<StillSource>(cv::Mat(36, 64, CV_8UC3, cv::Scalar(9)),
                                    50),
      clock, ViewOptions{.stale_after_ms = 100});
  CHECK(backend.source_status()->state == SourceState::kLive);
  std::this_thread::sleep_for(std::chrono::milliseconds(200));
  const auto status = backend.source_status();
  CHECK(status && status->state == SourceState::kStale &&
        status->detail.starts_with("unchanged for"));
}

// --- The crop -----------------------------------------------------------------

struct CropCase {
  std::string name;
  struct Input {
    cv::Size window;
    cv::Rect video;  // drawn into the window
    ViewOptions options;
  } input;
  struct Expectation {
    cv::Size frame;  // the backend's frames
  } expect;
};

const std::vector<CropCase> kCropCases = {
    {"no crop keeps the whole window",
     {{640, 400}, {100, 80, 320, 180}, {}},
     {{640, 400}}},
    {"a crop box cuts its part",
     {{640, 400}, {100, 80, 320, 180}, {.crop = Box{0.5, 0.25, 0.5, 0.5}}},
     {{320, 200}}},
    {"auto finds the 16:9 video",
     {{640, 400}, {100, 80, 320, 180}, {.find_crop = true}},
     {{320, 180}}},
    {"auto without a video keeps the window",
     {{640, 400}, {100, 80, 300, 200}, {.find_crop = true}},
     {{640, 400}}},
};

void check_crop() {
  const Clock clock;
  for (const CropCase& c : kCropCases) {
    ViewBackend backend(
        std::make_unique<StillSource>(
            window_with_video(c.input.window, c.input.video), 50),
        clock, c.input.options);
    // The area found may sit up to 2 px off the drawn edge.
    const cv::Size got(backend.info().width, backend.info().height);
    const bool ok = std::abs(got.width - c.expect.frame.width) <= 4 &&
                    std::abs(got.height - c.expect.frame.height) <= 4;
    if (!ok) {
      std::fprintf(stderr, "case: %s: got %dx%d\n", c.name.c_str(), got.width,
                   got.height);
    }
    CHECK(ok);
  }
}

// What moves: frames where only `moving` areas change, each by a new noise.
struct ChangeCase {
  std::string name;
  struct Input {
    std::vector<cv::Rect> moving;
    int frames = 4;
  } input;
  struct Expectation {
    std::optional<cv::Rect> video;
  } expect;
};

const std::vector<ChangeCase> kChangeCases = {
    {"a still window has no video", {{}, 4}, {std::nullopt}},
    {"a changing 16:9 area is the video",
     {{{100, 80, 320, 180}}, 4},
     {cv::Rect(100, 80, 320, 180)}},
    {"one frame shows nothing changed yet", {{{100, 80, 320, 180}}, 1},
     {std::nullopt}},
    {"a changing area that is not 16:9 is not",
     {{{100, 80, 300, 200}}, 4},
     {std::nullopt}},
    {"a small changing counter beside the video is left out",
     {{{100, 80, 320, 180}, {500, 350, 60, 12}}, 4},
     {cv::Rect(100, 80, 320, 180)}},
};

void check_change_area() {
  for (const ChangeCase& c : kChangeCases) {
    ChangeArea area;
    for (int i = 0; i < c.input.frames; i++) {
      cv::Mat frame(400, 640, CV_8UC3, cv::Scalar(40, 40, 40));
      for (const cv::Rect& box : c.input.moving) {
        cv::randu(frame(box), cv::Scalar(0, 0, 0), cv::Scalar(255, 255, 255));
      }
      area.add(frame);
    }
    const auto got = area.video_area();
    if (got != c.expect.video) {
      std::fprintf(stderr, "case: %s\n", c.name.c_str());
    }
    CHECK(got == c.expect.video);
  }
}

// --- The window's visibility --------------------------------------------------

struct VisibilityCase {
  std::string name;
  struct Input {
    cv::Rect2d target;
    bool on_screen = true;
    std::vector<ScreenWindow> in_front;
  } input;
  struct Expectation {
    SourceStatus status;
  } expect;
};

const cv::Rect2d kTarget(0, 0, 1000, 800);

const std::vector<VisibilityCase> kVisibilityCases = {
    {"nothing in front", {kTarget, true, {}},
     {{SourceState::kLive, "100% of the window shows"}}},
    {"a strip left shows: still live (its app keeps painting)",
     {kTarget, true, {{{100, -10, 2000, 900}, "Lab"}}},
     {{SourceState::kLive, "9% of the window shows"}}},
    {"one window over all of it",
     {kTarget, true, {{{-5, -5, 1100, 900}, "Lab"}}},
     {{SourceState::kCovered, "covered by Lab"}}},
    {"two windows together cover it: named by the larger share",
     {kTarget,
      true,
      {{{0, 0, 300, 800}, "Small"}, {{300, 0, 700, 800}, "Big"}}},
     {{SourceState::kCovered, "covered by Big"}}},
    {"not on screen", {kTarget, false, {}},
     {{SourceState::kHidden, "the window is not on screen"}}},
};

void check_visibility() {
  for (const VisibilityCase& c : kVisibilityCases) {
    const SourceStatus got = window_visibility(
        c.input.target, c.input.on_screen, c.input.in_front);
    if (!(got == c.expect.status)) {
      std::fprintf(stderr, "case: %s: got %s, %s\n", c.name.c_str(),
                   source_state_name(got.state), got.detail.c_str());
    }
    CHECK(got == c.expect.status);
  }
  CHECK(source_status_json({SourceState::kCovered, "covered by Lab"}) ==
        "{\"detail\":\"covered by Lab\",\"state\":\"covered\"}");
}

// --- The log tail -------------------------------------------------------------

void append(const std::string& path, const std::string& text) {
  pa::FileIO file(path, pa::FileMode::APPEND | pa::FileMode::BINARY);
  file.write(text);
}

void check_log_tail() {
  const std::string path =
      std::string(GAMEPILOT_TEST_OUTPUT_DIR) + "/view_source_test.log";
  pa::Filesystem::remove(path);
  LogTail tail(path, /*backlog_bytes=*/10);
  CHECK(tail.poll().empty());  // no file yet
  append(path, "old line one\nold two\nthree");
  // Starts in the last 10 bytes, from the first whole line in them.
  CHECK(tail.poll().empty());  // "three" has no end yet
  append(path, " ends\r\nfour\n");
  CHECK((tail.poll() == std::vector<std::string>{"three ends", "four"}));
  CHECK(tail.poll().empty());
  pa::Filesystem::remove(path);
  append(path, "new\n");  // replaced by a shorter file: from its start
  CHECK((tail.poll() == std::vector<std::string>{"new"}));
  pa::Filesystem::remove(path);
}

}  // namespace

int main() {
  init_sockets();
  check_server_refuses_input();
  check_stale_detector();
  check_backend_goes_stale();
  check_crop();
  check_change_area();
  check_visibility();
  check_log_tail();
  return TEST_RESULT();
}
