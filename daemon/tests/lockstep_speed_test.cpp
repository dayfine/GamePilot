// A lockstep backend at a speed: the server steps a fake emulator S times as
// fast as its frame rate, presses and waits keep their frame counts, and a
// frame's or a batch_done's t_ms is game time (frames x 1000 / frame_rate),
// so a program's waits and timeouts mean the same at every speed.

#include <atomic>
#include <chrono>
#include <cstdint>
#include <map>
#include <opencv2/core.hpp>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include "backend.h"
#include "check.h"
#include "clock.h"
#include "net.h"
#include "rpc.h"
#include "server.h"

using namespace gamepilot;

namespace {

constexpr double kGbaFrameRate = 59.7275;

// An emulator held in lockstep that renders a blank frame in no time.
class FakeLockstep : public Backend {
 public:
  FakeLockstep()
      : info_{"mgba",
              "BPRE",
              kGbaFrameRate,
              240,
              160,
              Viewport{Box{0, 0, 1, 1}, 240, 160}} {}

  const BackendInfo& info() const override { return info_; }
  std::int64_t seq() const override { return seq_; }
  void set_keys(KeyMask) override {}
  std::int64_t step() override { return ++seq_; }
  cv::Mat frame() override {
    return cv::Mat(info_.height, info_.width, CV_8UC3, cv::Scalar(0));
  }
  std::int64_t load_state(const std::string&) override { return seq_; }
  std::int64_t save_state(const std::string&) override { return seq_; }
  void release() override {}

 private:
  BackendInfo info_;
  std::int64_t seq_ = 1000;
};

struct SpeedCase {
  std::string name;
  struct Input {
    double speed = 1;
    std::string commands;  // the submit's `commands`, JSON
  } input;
  struct Expectation {
    std::int64_t frames = 0;  // batch_done seq - start_seq
  } expect;
};

const std::vector<SpeedCase> kSpeedCases = {
    {"a 1000 ms wait at 1x", {1, R"([{"wait_ms":1000}])"}, {60}},
    {"a 1000 ms wait at 2x", {2, R"([{"wait_ms":1000}])"}, {60}},
    {"a 1000 ms wait at 4x", {4, R"([{"wait_ms":1000}])"}, {60}},
    // Two tiles of walking at every speed, not two tiles per wall second.
    {"a 1068 ms hold at 4x",
     {4, R"([{"press":["Right"],"hold_ms":1068,"cooldown_ms":0}])"},
     {64}},
};

struct Notice {
  std::string method;
  pa::JsonObject params;
};

// Reads lines until one answers `id` or is a `method` notification.
class TestClient {
 public:
  explicit TestClient(std::uint16_t port) : socket_(connect_local(port)) {}

  pa::JsonObject call(int id, const std::string& method,
                      const std::string& params) {
    const pa::JsonObject answer = request(id, method, params);
    const pa::JsonObject* result = answer.get_object("result");
    CHECK(result != nullptr);
    return result != nullptr ? result->clone() : pa::JsonObject();
  }

  // The whole answer to a request: its result or its error.
  pa::JsonObject request(int id, const std::string& method,
                         const std::string& params) {
    const std::string line = R"({"jsonrpc":"2.0","id":)" + std::to_string(id) +
                             R"(,"method":")" + method +
                             R"(","params":)" + params + "}";
    CHECK(socket_.send_all(line + "\n"));
    while (true) {
      const pa::JsonValue message = next();
      const pa::JsonObject& object = *message.to_object();
      if (object.get_integer_default("id", -1) == id) {
        return object.clone();
      }
    }
  }

  // The next `method` notification; frames on the way are kept in frames_.
  pa::JsonObject wait_for(const std::string& method) {
    while (true) {
      const pa::JsonValue message = next();
      const pa::JsonObject& object = *message.to_object();
      if (object.get_string_default("method") == method) {
        return object.get_object_throw("params").clone();
      }
    }
  }

  // t_ms of each frame seen, by seq.
  const std::map<std::int64_t, double>& frames() const { return frames_; }

 private:
  pa::JsonValue next() {
    while (true) {
      if (auto line = lines_.next_line()) {
        pa::JsonValue message = parse_message(*line);
        const pa::JsonObject& object = *message.to_object();
        if (object.get_string_default("method") == "frame") {
          const pa::JsonObject& params = object.get_object_throw("params");
          frames_[params.get_integer_throw("seq")] =
              params.get_double_throw("t_ms");
        }
        return message;
      }
      if (poll_readable({&socket_}, 1000)[0]) {
        const auto data = socket_.receive_some();
        if (!data) {
          throw std::runtime_error("server closed the connection");
        }
        lines_.append(*data);
      } else {
        throw std::runtime_error("no message in 1 s");
      }
    }
  }

  Socket socket_;
  LineBuffer lines_;
  std::map<std::int64_t, double> frames_;
};

double wall_ms_since(std::chrono::steady_clock::time_point start) {
  return std::chrono::duration<double, std::milli>(
             std::chrono::steady_clock::now() - start)
      .count();
}

void check_speed(const SpeedCase& c) {
  const Clock clock;
  FakeLockstep backend;
  ServerOptions options;
  options.port = 0;
  options.speed = c.input.speed;
  Server server(backend, options, clock);
  std::atomic<bool> stop{false};
  std::thread serving([&] { server.run(stop); });
  try {
    TestClient client(server.port());
    client.call(1, "hello", R"({"protocol":1,"client":"speed-test"})");
    client.call(
        2, "subscribe",
        R"({"probes":[{"id":"p","kind":"core.color_stats@1","box":{"x":0,"y":0,"w":1,"h":1},"delivery":"every"}]})");
    client.wait_for("frame");
    const auto submitted = std::chrono::steady_clock::now();
    const pa::JsonObject result =
        client.call(3, "submit",
                    R"({"batch_id":"b1","commands":)" + c.input.commands + "}");
    const pa::JsonObject done = client.wait_for("batch_done");
    const double wall_ms = wall_ms_since(submitted);

    const std::int64_t start_seq = result.get_integer_throw("start_seq");
    const std::int64_t end_seq = done.get_integer_throw("seq");
    const std::int64_t frames = end_seq - start_seq;
    // Game time: frames at the GBA's rate, whatever the speed.
    const double game_ms = static_cast<double>(frames) * 1000 / kGbaFrameRate;
    const auto start_frame = client.frames().find(start_seq);
    const bool found = start_frame != client.frames().end();
    const double t_ms_span =
        found ? done.get_double_throw("t_ms") - start_frame->second : -1;
    // Wall time: game time over the speed, with room for a loaded machine.
    const double expected_wall_ms = game_ms / c.input.speed;
    const bool ok = frames == c.expect.frames && found &&
                    std::abs(t_ms_span - game_ms) <= 0.2 &&
                    wall_ms >= expected_wall_ms * 0.9 &&
                    wall_ms <= expected_wall_ms * 1.5 + 50;
    if (!ok) {
      std::fprintf(stderr,
                   "case: %s: %lld frames, t_ms span %.1f (game %.1f), wall "
                   "%.0f ms (expected %.0f)\n",
                   c.name.c_str(), static_cast<long long>(frames), t_ms_span,
                   game_ms, wall_ms, expected_wall_ms);
    }
    CHECK(ok);
  } catch (const std::exception& error) {
    std::fprintf(stderr, "case: %s: %s\n", c.name.c_str(), error.what());
    CHECK(false);
  }
  stop.store(true);
  serving.join();
}

// mGBA has no Home: a press of it is refused, naming the button, and runs
// nothing.
void check_home_refused() {
  const Clock clock;
  FakeLockstep backend;
  ServerOptions options;
  options.port = 0;
  Server server(backend, options, clock);
  std::atomic<bool> stop{false};
  std::thread serving([&] { server.run(stop); });
  try {
    TestClient client(server.port());
    client.call(1, "hello", R"({"protocol":1,"client":"home-test"})");
    const pa::JsonObject answer = client.request(
        2, "submit",
        R"({"batch_id":"h","commands":[{"press":["Home"],"hold_ms":50,"cooldown_ms":50}]})");
    const pa::JsonObject* error = answer.get_object("error");
    CHECK(
        error != nullptr &&
        error->get_integer_default("code") == kInvalidParams &&
        error->get_object_throw("data").get_string_throw("button") == "Home" &&
        error->get_object_throw("data").get_string_throw("backend") == "mgba");
  } catch (const std::exception& error) {
    std::fprintf(stderr, "home refused: %s\n", error.what());
    CHECK(false);
  }
  stop.store(true);
  serving.join();
}

}  // namespace

int main() {
  for (const SpeedCase& c : kSpeedCases) {
    check_speed(c);
  }
  check_home_refused();
  return TEST_RESULT();
}
