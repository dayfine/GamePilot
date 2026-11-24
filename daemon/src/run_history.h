// The runs folder ($GAMEPILOT_RUNS) as the hub's runs list and its page of a
// finished run read it (watch_hub.h). One folder per run:
//
//   run.json         what the runner says of the run, written at its start and
//                    again at its end: the registry's program (game,
//                    game_name, program, program_name, group), the series'
//                    range (from, to), checkpoint, backend, mode, started_ms,
//                    and at the end ended_ms, result, at, reason
//   daemon.json, watch_plan.json, watch_run.json, watch_log.jsonl
//                    the daemon's notes (run_journal.h)
//   frames/          recorded frames and their index (frame_stream.h)
//   story.log, summary.txt, failure.png, wire.jsonl, daemon.out
//   ../RESULTS.tsv   one row per finished run
//
// A folder without run.json falls back to its name
// (<date>-<checkpoint>-<mode>-<n>), its RESULTS.tsv row and its daemon's first
// output line (the backend). Its start is daemon.json's clock_zero_unix_ms,
// else the first wire.jsonl line (the log's span back from its last write),
// else the folder's mtime; its end the last wire.jsonl line; its result
// "unknown". So every row has a start and sorts by it. Game and program are
// then unknown: the daemon has no game names (`gamepilot runs --backfill`
// writes run.json for such folders).

#pragma once

#include <cstdint>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <string_view>
#include <vector>

namespace gamepilot {

struct RunRow {
  std::string run;  // the folder's name
  // checkpoints, checkpoint, program, preflight, bring-up, daemon
  std::string kind;
  std::string game;  // the registry's ids: frlg, frlg.mail_glitch
  std::string game_name;
  std::string program;
  std::string program_name;
  std::string group;  // "FRLG / Glitches"
  std::string from;  // the series' first and last checkpoint
  std::string to;
  std::string checkpoint;
  std::string backend;  // mgba, switch; empty = unknown
  std::string mode;
  std::string result;  // pass, fail, running, unknown
  std::string at;      // where it failed
  std::string reason;
  std::int64_t started_ms = 0;  // Unix ms
  std::int64_t ended_ms = 0;
  bool live = false;
  bool recorded = false;  // has frames/
  bool failure_frame = false;  // has failure.png
};

// A run folder's name: no path parts, nothing hidden.
bool valid_run_name(std::string_view name);

// "<YYYY-MM-DD>-<checkpoint>-<mode>-<n>": checkpoint, mode (testing,
// verification, preflight, single, run, bring-up: Run_record's).
struct RunName {
  std::string checkpoint;
  std::string mode;
  bool operator==(const RunName&) const = default;
};
std::optional<RunName> parse_run_name(std::string_view name);

// RESULTS.tsv's rows by run name, each keyed by the header's column names.
using ResultRows = std::map<std::string, std::map<std::string, std::string>>;
ResultRows results_by_run(std::string_view results_tsv);

// RESULTS.tsv's local time ("2026-11-23T21:57:22") as Unix ms; 0 when bad.
std::int64_t local_time_ms(std::string_view text);

// The t_ms of a wire log's last line (how long the daemon ran); 0 when none.
double wire_log_end_ms(const std::string& path);
// The t_ms of a wire log's first line; 0 when none.
double wire_log_start_ms(const std::string& path);

// A file's or folder's last change, Unix ms; 0 when it has none.
std::int64_t mtime_ms(const std::string& path);

// One run folder, `run.json` first, then the fallbacks.
RunRow read_run(const std::string& runs_dir, const std::string& name,
                const ResultRows& results);

// Every run folder, newest first; `live` names the runs whose daemon is up.
std::vector<RunRow> list_runs(const std::string& runs_dir,
                              std::string_view results_tsv,
                              const std::set<std::string>& live);

std::string run_row_json(const RunRow& row);
std::string run_rows_json(const std::vector<RunRow>& rows);

// A run folder's file the hub may serve, by its path in the folder: the
// notes, the log, the failure frame, the recorded frames and their index.
// Never wire.jsonl (tens of MB: the probe timeline summarizes it).
bool servable_run_file(std::string_view path);
std::string_view run_file_type(std::string_view path);

// The probe values over a run from its wire.jsonl (or wire.jsonl.gz: a path
// ending in .gz is read through gzip), read a chunk at a time, from the
// program's connection only (the one that spoke first; other clients' frames,
// such as a `gamepilot ctl read`, are left out):
// one number per probe (color_stats: the mean of its channel means;
// color_count: fraction; template_match: score), the last value in each
// `bucket_ms` of daemon time, kept only when it changed. JSON:
//   {"bucket_ms", "t0_ms", "t1_ms", "lines", "probes": {ID: {"kind",
//    "points": [[t_ms, value], ...]}}}
std::string probe_timeline_json(const std::string& wire_log, double bucket_ms);

}  // namespace gamepilot
