// press_latency: the latency harness (press_latency.h) as a command.
//
//   press_latency --fake [--response-ms 50] [--fps 60] [--presses 20]
//                 [--hold-ms 100]
//
// --fake runs it on FakeSwitch: its screen turns bright `response-ms` after a
// press starts on the board, so the result should be that plus up to one
// frame. On the console it will run on the capture card and the controller
// board (not wired up yet: the board's session handshake comes first).

#include <cstdio>
#include <cstdlib>
#include <exception>
#include <string>
#include <string_view>

#include "fake_switch.h"
#include "press_latency.h"
#include "switch_backend.h"

namespace {

int usage() {
  std::fputs(
      "usage: press_latency --fake [--response-ms 50] [--fps 60] "
      "[--presses 20] [--hold-ms 100]\n",
      stderr);
  return 2;
}

bool parse_number(const char* text, double& value) {
  char* end = nullptr;
  value = std::strtod(text, &end);
  return end != text && *end == '\0' && value >= 0;
}

}  // namespace

int main(int argc, char** argv) {
  bool fake = false;
  double response_ms = 50;
  double fps = 60;
  double presses = 20;
  gamepilot::PressLatencyPlan plan;
  for (int i = 1; i < argc; i++) {
    const std::string_view arg = argv[i];
    const bool has_value = i + 1 < argc;
    if (arg == "--fake") {
      fake = true;
    } else if (arg == "--response-ms" && has_value) {
      if (!parse_number(argv[++i], response_ms)) {
        return usage();
      }
    } else if (arg == "--fps" && has_value) {
      if (!parse_number(argv[++i], fps) || fps <= 0) {
        return usage();
      }
    } else if (arg == "--presses" && has_value) {
      if (!parse_number(argv[++i], presses) || presses < 1) {
        return usage();
      }
    } else if (arg == "--hold-ms" && has_value) {
      if (!parse_number(argv[++i], plan.hold_ms)) {
        return usage();
      }
    } else {
      return usage();
    }
  }
  if (!fake) {
    return usage();
  }
  plan.presses = static_cast<int>(presses);

  try {
    const gamepilot::Clock clock;
    constexpr std::uint32_t kSession = 0x47500001;
    gamepilot::FakeSwitch board(clock, kSession);
    gamepilot::Pabb2Controller controller(board, kSession);
    const auto attached = board.attach(controller);
    controller.reset();
    gamepilot::SwitchBackend backend(
        board.screen(fps, response_ms, cv::Size(320, 180)), controller, clock,
        gamepilot::SwitchOptions{});
    const gamepilot::PressLatencyReport report =
        gamepilot::measure_press_latency(backend, clock, plan);
    const auto& l = report.latencies_ms;
    std::printf(
        "press_latency (fake: response %.0f ms, %.0f fps, frame %.1f ms)\n",
        response_ms, fps, report.frame_ms);
    std::printf("presses %d, misses %d\n", plan.presses, report.misses);
    std::printf(
        "press -> changed frame ms: min %.1f, median %.1f, p90 %.1f, p99 "
        "%.1f, max %.1f\n",
        gamepilot::percentile(l, 0), gamepilot::percentile(l, 0.5),
        gamepilot::percentile(l, 0.9), gamepilot::percentile(l, 0.99),
        gamepilot::percentile(l, 1));
    std::printf("spread (p99 - median) ms: %.1f\n",
                gamepilot::percentile(l, 0.99) - gamepilot::percentile(l, 0.5));
    return report.misses == 0 ? 0 : 1;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "press_latency: %s\n", error.what());
    return 1;
  }
}
