// A checkpoint series' record in the watch registry,
// `<registry>/series/<id>.json`: the runner writes it (src/core/live_run's
// Series_watch) and rewrites it whole at each change, since each run of the
// series has its own daemon and no daemon knows the series. The hub reads it
// to list the series as one entry and to pass the series' page through to the
// daemon of the run going (watch_hub.h, Watch-Page.md, One page per series).
// The hub only routes by it; the page shows the rest of the record as it is.

#pragma once

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

#include "watch_registry.h"

namespace gamepilot {

struct SeriesRecord {
  std::string id;                 // its name in the hub's /series/ID/
  std::int64_t pid = 0;           // the runner's
  std::int64_t started_ms = 0;    // Unix ms
  std::string result;             // "running", "pass" or "fail"
  std::string run;                // the run going (its folder's name); empty
                                  // between runs
  std::vector<std::string> runs;  // every run's folder name, in run order
  std::string json;               // the record as the runner wrote it
};

// Nothing for a file that is not a record (or names an id no URL can carry).
std::optional<SeriesRecord> parse_series_record(const std::string& json);

// The record of series `id` in the registry, live or not.
std::optional<SeriesRecord> read_series_record(const std::string& registry,
                                               const std::string& id);

// The series in the registry that are running: their runner lives (`alive`)
// and has not ended them. Oldest first.
std::vector<SeriesRecord> live_series(
    const std::string& registry,
    const std::function<bool(std::int64_t)>& alive = process_alive);

// The records as /series.json gives them: a list of the records as written.
std::string hub_series_json(const std::vector<SeriesRecord>& series);

// The series a run belongs to, else nothing.
const SeriesRecord* series_of_run(const std::vector<SeriesRecord>& series,
                                  const std::string& run);

}  // namespace gamepilot
