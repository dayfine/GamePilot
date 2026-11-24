// The Switch backend without a console: the key mapping, the wall-time input
// schedule, the capture ring's gaps and heartbeat, a
// recorded clip played at its own rate, the latency harness on FakeSwitch, and
// `status` from a second connection while a client is served.

#include "switch_backend.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/videoio.hpp>
#include <string>
#include <thread>
#include <vector>

#include "check.h"
#include "fake_console.h"
#include "live_schedule.h"
#include "net.h"
#include "press_latency.h"
#include "rpc.h"
#include "server.h"

using namespace gamepilot;

namespace {

constexpr KeyMask kA = 1u << 0;
constexpr KeyMask kRight = 1u << 4;
constexpr KeyMask kLeft = 1u << 5;
constexpr KeyMask kUp = 1u << 6;
constexpr KeyMask kDown = 1u << 7;

void sleep_ms(int ms) {
  std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

void check_key_mapping() {
  // Report 0x30's byte 5: Down, Up, Right, Left in bits 0-3.
  CHECK(pro_buttons_for_keys(kUp | kRight).button5 == 0x06);
  CHECK(pro_buttons_for_keys(kDown | kLeft).button5 == 0x09);
  // Opposite arrows cancel.
  CHECK(pro_buttons_for_keys(kUp | kDown).button5 == 0);
  CHECK(pro_buttons_for_keys(kLeft | kRight | kA).button5 == 0);
}

void check_live_schedule() {
  LiveSchedule schedule;
  InputCommand press;
  press.buttons = kA;
  press.hold_ms = 100;
  press.cooldown_ms = 50;
  InputCommand wait;
  wait.is_wait = true;
  wait.wait_ms = 200;
  CHECK(schedule.submit("b1", {press, wait}, 1000) == 1000);
  // Queued after b1, which ends at 1350.
  CHECK(schedule.submit("b2", {press}, 1100) == 1350);
  CHECK(schedule.next_event_ms() == 1000.0);

  const auto first = schedule.take_due(1000);
  CHECK(first.size() == 1 && first[0].keys == kA && first[0].ms == 100);
  const auto next = schedule.take_due(1349);
  CHECK(next.size() == 2);
  CHECK(next[0].start_ms == 1100 && next[0].keys == 0 && next[0].ms == 50);
  CHECK(next[1].start_ms == 1150 && next[1].ms == 200);
  CHECK(schedule.take_finished(1349).empty());
  const auto ended = schedule.take_finished(1350);
  CHECK(ended.size() == 1 && ended[0].batch_id == "b1");
  schedule.clear();
  CHECK(!schedule.next_event_ms());
}

// Frame 1 at once, then frames 2..`total` as fast as they go once `open()` is
// called, then stalls until destroyed.
class GatedSource : public FrameSource {
 public:
  explicit GatedSource(int total) : total_(total) {}
  ~GatedSource() override { finish(); }

  bool read(cv::Mat& frame) override {
    std::unique_lock<std::mutex> guard(lock_);
    if (served_ > 0) {
      changed_.wait(guard,
                    [&] { return finished_ || (open_ && served_ < total_); });
      if (finished_) {
        return false;
      }
    }
    served_++;
    frame = cv::Mat(4, 4, CV_8UC3, cv::Scalar::all(served_));
    return true;
  }
  double frame_rate() const override { return 60; }

  void open() {
    std::lock_guard<std::mutex> guard(lock_);
    open_ = true;
    changed_.notify_all();
  }
  void finish() {
    std::lock_guard<std::mutex> guard(lock_);
    finished_ = true;
    changed_.notify_all();
  }

 private:
  std::mutex lock_;
  std::condition_variable changed_;
  int total_;
  int served_ = 0;
  bool open_ = false;
  bool finished_ = false;
};

ThreadBeat capture_beat(const Backend& backend) {
  return backend.health().threads.at(0);
}

// A full ring drops the oldest frames; the reader sees the jump as one gap.
// A capture that stops delivering stops its heartbeat.
void check_gaps_and_stalled_capture() {
  const Clock clock;
  test::FakeConsole console(clock);
  auto owned = std::make_unique<GatedSource>(10);
  GatedSource& source = *owned;
  SwitchOptions options;
  options.ring_capacity = 3;
  SwitchBackend backend(std::move(owned), console.session, clock, options);
  CHECK(backend.info().timing == Timing::kLive);
  CHECK(backend.info().width == 4 && backend.info().height == 4);

  const auto first = backend.next_frame(100);
  CHECK(first && first->seq == 1);
  source.open();
  for (int i = 0; i < 500 && capture_beat(backend).seq < 10; i++) {
    sleep_ms(1);
  }
  CHECK(capture_beat(backend).seq == 10);
  CHECK(backend.health().ring_depth == 3);
  const auto after = backend.next_frame(100);
  CHECK(after && after->seq == 8);
  CHECK(backend.health().gaps == 1);
  CHECK(backend.health().gap_frames == 6);  // 2..7

  // The source now stalls: the capture heartbeat stays where it was.
  const double beat_ms = capture_beat(backend).t_ms;
  sleep_ms(100);
  CHECK(capture_beat(backend).t_ms == beat_ms);
  CHECK(clock.now_ms() - beat_ms >= 100);
  source.finish();
}

// A short clip made from Switch screenshots plays at its own frame rate.
void check_video_replay() {
  const std::string dir = GAMEPILOT_SWITCH_IMAGES_DIR;
  const std::vector<std::string> names = {"01-bag-items",
                                          "02-bag-key-items",
                                          "03-key-items-tmcase-selected",
                                          "04-tmcase-after-A",
                                          "05-tmcase-list",
                                          "07-tm-use-party",
                                          "12-forget-move-list",
                                          "16-summary-moves-after-teach"};
  const std::string clip = std::string(GAMEPILOT_TEST_OUTPUT_DIR) + "/clip.avi";
  constexpr double kFps = 60;
  {
    cv::VideoWriter writer(clip, cv::CAP_OPENCV_MJPEG,
                           cv::VideoWriter::fourcc('M', 'J', 'P', 'G'), kFps,
                           cv::Size(1920, 1080));
    CHECK(writer.isOpened());
    for (const std::string& name : names) {
      const cv::Mat image = cv::imread(dir + "/" + name + ".png");
      CHECK(image.cols == 1920 && image.rows == 1080);
      writer.write(image);
    }
  }

  const Clock clock;
  test::FakeConsole console(clock);
  SwitchBackend backend(open_video_replay(clip, clock), console.session, clock,
                        SwitchOptions{});
  CHECK(backend.info().width == 1920 && backend.info().height == 1080);
  CHECK(std::abs(backend.info().frame_rate - kFps) < 0.01);
  std::vector<FrameStamp> stamps;
  std::vector<double> means;
  for (int i = 0; i < 100 && stamps.size() < names.size(); i++) {
    if (const auto stamp = backend.next_frame(50)) {
      stamps.push_back(*stamp);
      means.push_back(cv::mean(backend.frame())[0]);
    }
  }
  CHECK(stamps.size() == names.size());
  if (stamps.size() != names.size()) {
    return;
  }
  for (std::size_t i = 0; i < stamps.size(); i++) {
    CHECK(stamps[i].seq == static_cast<std::int64_t>(i + 1));
  }
  // 7 frame periods from the first frame to the last, not as fast as decoding.
  const double span = stamps.back().t_ms - stamps.front().t_ms;
  const double expected = 1000.0 / kFps * static_cast<double>(names.size() - 1);
  CHECK(span >= expected - 5 && span <= expected + 100);
  // The frames are the screenshots, not one repeated.
  CHECK(means.front() != means.back());
}

void check_latency_harness() {
  const Clock clock;
  test::FakeConsole console(clock);
  constexpr double kResponseMs = 50;
  SwitchBackend backend(console.board.screen(60, kResponseMs, cv::Size(64, 36)),
                        console.session, clock, SwitchOptions{});
  PressLatencyPlan plan;
  plan.presses = 5;
  plan.settle_ms = 200;
  const PressLatencyReport report = measure_press_latency(backend, clock, plan);
  CHECK(report.misses == 0);
  CHECK(report.latencies_ms.size() == 5);
  // The response time plus up to a frame, with room for a loaded machine.
  CHECK(percentile(report.latencies_ms, 0) >= kResponseMs);
  CHECK(percentile(report.latencies_ms, 1) <=
        kResponseMs + report.frame_ms + 50);
}

// Writes one request line and reads one reply line.
std::string call(Socket& socket, const std::string& line) {
  CHECK(socket.send_all(line + "\n"));
  LineBuffer lines;
  for (int i = 0; i < 200; i++) {
    if (poll_readable({&socket}, 10)[0]) {
      const auto data = socket.receive_some();
      if (!data) {
        break;
      }
      lines.append(*data);
      if (auto reply = lines.next_line()) {
        return *reply;
      }
    }
  }
  return "";
}

// A client is connected; a second connection still gets `status`, and only
// that.
void check_status_while_serving() {
  const Clock clock;
  test::FakeConsole console(clock);
  SwitchBackend backend(console.board.screen(60, 0, cv::Size(64, 36)),
                        console.session, clock, SwitchOptions{});
  ServerOptions options;
  options.port = 47977;
  Server server(backend, options);
  std::atomic<bool> stop{false};
  std::thread serving([&] { server.run(stop); });

  Socket client = connect_local(options.port);
  const std::string hello = call(
      client,
      R"({"jsonrpc":"2.0","id":1,"method":"hello","params":{"protocol":1,"client":"switch-test"}})");
  CHECK(hello.find("\"kind\":\"switch\"") != std::string::npos);
  sleep_ms(50);

  Socket observer = connect_local(options.port);
  const pa::JsonValue status = parse_message(
      call(observer, R"({"jsonrpc":"2.0","id":7,"method":"status"})"));
  const pa::JsonObject& result = status.to_object()->get_object_throw("result");
  CHECK(result.get_string_throw("backend") == "switch");
  CHECK(result.get_string_throw("client") == "switch-test");
  CHECK(result.get_string_throw("fidelity") == "latest");
  const pa::JsonArray& threads = result.get_array_throw("threads");
  CHECK(threads.size() == 2);
  if (threads.size() == 2) {
    const double now = result.get_double_throw("t_ms");
    for (const pa::JsonValue& thread : threads) {
      const pa::JsonObject& beat = *thread.to_object();
      CHECK(beat.get_integer_throw("seq") > 0);
      CHECK(now - beat.get_double_throw("t_ms") < 500);
    }
    CHECK(threads[0].to_object()->get_string_throw("name") == "capture");
    CHECK(threads[1].to_object()->get_string_throw("name") == "server");
  }
  CHECK(result.get_object_throw("ring").get_integer_throw("capacity") == 8);

  const std::string refused = call(
      observer,
      R"({"jsonrpc":"2.0","id":8,"method":"submit","params":{"batch_id":"x","commands":[]}})");
  CHECK(refused.find("\"error\"") != std::string::npos);

  stop.store(true);
  serving.join();
}

}  // namespace

int main() {
  init_sockets();
  check_key_mapping();
  check_live_schedule();
  check_gaps_and_stalled_capture();
  check_video_replay();
  check_latency_harness();
  check_status_while_serving();
  return TEST_RESULT();
}
