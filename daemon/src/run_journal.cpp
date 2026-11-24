#include "run_journal.h"

#include <cstdio>
#include <utility>

#include "Common/Cpp/Filesystem/Filesystem.h"
#include "watch_registry.h"

namespace gamepilot {

std::string daemon_record_json(const DaemonRecord& record) {
  pa::JsonObject json;
  json["backend"] = record.backend;
  json["clock_zero_unix_ms"] =
      static_cast<std::int64_t>(record.clock_zero_unix_ms);
  json["record"] = record.record;
  json["keepawake_s"] = record.keepawake_s;
  return to_line(pa::JsonValue(std::move(json)));
}

std::string daemon_run_json(const std::string& run, const DaemonRecord& record,
                            const std::string& label, std::int64_t ended_ms) {
  pa::JsonObject json;
  json["run"] = run;
  json["kind"] = "daemon";
  json["backend"] = record.backend;
  json["checkpoint"] = label;
  json["started_ms"] = static_cast<std::int64_t>(record.clock_zero_unix_ms);
  if (ended_ms > 0) {
    json["ended_ms"] = ended_ms;
  }
  return to_line(pa::JsonValue(std::move(json)));
}

PlanStep current_step(const pa::JsonObject& plan) {
  const pa::JsonArray* events = plan.get_array("events");
  if (events == nullptr) {
    return {};
  }
  for (const pa::JsonValue& event : *events) {
    const pa::JsonObject* object = event.to_object();
    if (object == nullptr) {
      continue;
    }
    const std::string* state = object->get_string("state");
    const std::string* id = object->get_string("id");
    if (state != nullptr && id != nullptr &&
        (*state == "current" || *state == "failed")) {
      return PlanStep{*id, *state == "failed"};
    }
  }
  return {};
}

RunJournal::RunJournal(std::string folder, const DaemonRecord& record,
                       std::string label)
    : folder_(std::move(folder)), record_(record), label_(std::move(label)) {
  write("daemon.json", daemon_record_json(record) + "\n");
  if (!pa::Filesystem::exists(folder_ + "/run.json")) {
    owns_run_json_ = true;
    write("run.json", daemon_run_json(run_name(), record_, label_, 0) + "\n");
  }
  if (!log_.open(folder_ + "/watch_log.jsonl",
                 pa::FileMode::APPEND | pa::FileMode::BINARY)) {
    warn("watch_log.jsonl");
  }
}

RunJournal::~RunJournal() {
  if (owns_run_json_) {
    write("run.json",
          daemon_run_json(run_name(), record_, label_, unix_now_ms()) + "\n");
  }
}

std::string RunJournal::run_name() const {
  return pa::Filesystem::Path(folder_).filename().string();
}

void RunJournal::plan(const std::string& json) {
  write("watch_plan.json", json + "\n");
}

void RunJournal::chain(const std::string& json) {
  write("watch_run.json", json + "\n");
}

void RunJournal::log_line(const pa::JsonObject& params, double unix_ms) {
  if (!log_.is_open()) {
    return;
  }
  pa::JsonObject line;
  line["unix_ms"] = static_cast<std::int64_t>(unix_ms);
  line["line"] = params.get_string_default("line", "");
  log_.write(to_line(pa::JsonValue(std::move(line))) + "\n");
  log_.flush();
}

void RunJournal::write(const std::string& name, const std::string& text) {
  pa::FileIO file;
  if (!file.open(folder_ + "/" + name,
                 pa::FileMode::WRITE | pa::FileMode::BINARY) ||
      file.write(text) != text.size()) {
    warn(name);
  }
}

void RunJournal::warn(const std::string& name) {
  if (!warned_) {
    warned_ = true;
    std::fprintf(stderr, "daemon: cannot write %s in %s\n", name.c_str(),
                 folder_.c_str());
  }
}

}  // namespace gamepilot
