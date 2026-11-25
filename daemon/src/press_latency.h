// The latency harness: press a button, time the first captured frame that
// shows it. Runs on any live backend: against FakeSwitch now, against the
// console later (the stack design's latency gate; PR #44, W6). The press has
// to show on screen at once (opening a menu), inside `box`.

#pragma once

#include <vector>

#include "backend.h"
#include "clock.h"

namespace gamepilot {

struct PressLatencyPlan {
  int presses = 20;
  KeyMask keys = 1;          // GBA A
  double hold_ms = 100;      // how long each press holds
  double settle_ms = 400;    // wait after each press for the screen to settle
  double timeout_ms = 1000;  // no change by then is a miss
  Box box{0, 0, 1, 1};       // where to look, normalized to the frame
  // Mean absolute difference from the frame before the press, 0..255, that
  // counts as a change.
  double threshold = 20;
};

struct PressLatencyReport {
  std::vector<double> latencies_ms;  // press sent -> changed frame captured
  int misses = 0;
  double frame_ms = 0;  // the backend's frame period
};

// Runs the plan on `backend`. Throws BackendError from the backend.
PressLatencyReport measure_press_latency(Backend& backend, const Clock& clock,
                                         const PressLatencyPlan& plan);

// The value at fraction q (0..1) of the sorted `values` (nearest rank).
double percentile(std::vector<double> values, double q);

}  // namespace gamepilot
