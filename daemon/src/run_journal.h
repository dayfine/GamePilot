// What the daemon keeps of a run in its run folder (--run-folder), so the
// hub's page of a finished run (watch_hub.h) shows what the live page showed:
//
//   daemon.json      the backend, when the daemon's clock read 0 (Unix ms:
//                    wire.jsonl's t_ms + this = Unix ms), recording and
//                    keep-awake as set
//   watch_plan.json  the program's latest watch.plan (each event and its times)
//   watch_run.json   the runner's latest watch.run (the chain)
//   watch_log.jsonl  each watch.log line with when it came: {"unix_ms", "line"}
//   run.json         only when the folder has none (a daemon started by hand:
//                    a runner writes its own first, Run_record in src/core):
//                    {"run", "kind": "daemon", "backend", "checkpoint" (its
//                    --checkpoint label), "started_ms"}, and "ended_ms" when
//                    the daemon stops
//
// The notes stay off the wire log (Watch-Page.md); these files are the run's
// record of them. A file that cannot be written is reported once and skipped:
// the run goes on.

#pragma once

#include <cstdint>
#include <string>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "rpc.h"

namespace gamepilot {

struct DaemonRecord {
  std::string backend;
  double clock_zero_unix_ms = 0;
  bool record = false;
  double keepawake_s = 0;  // 0 = off
};

std::string daemon_record_json(const DaemonRecord& record);

// The run.json of a daemon started by hand: `run` the folder's name, `label`
// its --checkpoint; no ended_ms while `ended_ms` is 0.
std::string daemon_run_json(const std::string& run, const DaemonRecord& record,
                            const std::string& label, std::int64_t ended_ms);

// The event a watch.plan is at: the first `failed` or `current` one (its id,
// and whether it failed); an empty id when none is.
struct PlanStep {
  std::string id;
  bool failed = false;
  bool operator==(const PlanStep&) const = default;
};
PlanStep current_step(const pa::JsonObject& plan);

class RunJournal {
 public:
  RunJournal(std::string folder, const DaemonRecord& record,
             std::string label = {});
  // The end in the run.json it wrote, if it wrote one.
  ~RunJournal();
  RunJournal(const RunJournal&) = delete;
  RunJournal& operator=(const RunJournal&) = delete;

  void plan(const std::string& json);
  void chain(const std::string& json);
  // A watch.log note's params ({"line": ...}) and when it came.
  void log_line(const pa::JsonObject& params, double unix_ms);

 private:
  void write(const std::string& name, const std::string& text);
  void warn(const std::string& name);
  std::string run_name() const;

  std::string folder_;
  DaemonRecord record_;
  std::string label_;
  bool owns_run_json_ = false;
  pa::FileIO log_;
  bool warned_ = false;
};

}  // namespace gamepilot
