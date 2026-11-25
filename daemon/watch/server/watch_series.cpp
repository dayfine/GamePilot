#include "watch_series.h"

#include <algorithm>
#include <exception>
#include <string_view>

#include "Common/Cpp/Exceptions.h"
#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "rpc.h"
#include "run_history.h"

namespace gamepilot {

namespace fs = pa::Filesystem;

namespace {

constexpr std::string_view kSuffix = ".json";

std::string series_dir(const std::string& registry) {
  return registry + "/series";
}

std::string trimmed(const std::string& text) {
  const std::size_t end = text.find_last_not_of(" \t\r\n");
  return end == std::string::npos ? std::string() : text.substr(0, end + 1);
}

std::vector<std::string> run_names(const pa::JsonObject& record) {
  std::vector<std::string> names;
  const pa::JsonArray* checkpoints = record.get_array("checkpoints");
  if (checkpoints == nullptr) {
    return names;
  }
  for (const pa::JsonValue& checkpoint : *checkpoints) {
    const pa::JsonObject* object = checkpoint.to_object();
    const pa::JsonArray* runs =
        object == nullptr ? nullptr : object->get_array("runs");
    if (runs == nullptr) {
      continue;
    }
    for (const pa::JsonValue& run : *runs) {
      const pa::JsonObject* r = run.to_object();
      if (r != nullptr && r->get_string("run") != nullptr) {
        names.push_back(*r->get_string("run"));
      }
    }
  }
  return names;
}

}  // namespace

std::optional<SeriesRecord> parse_series_record(const std::string& json) {
  try {
    const pa::JsonValue value = pa::parse_json(json);
    const pa::JsonObject* object = value.to_object();
    if (object == nullptr) {
      return std::nullopt;
    }
    SeriesRecord record;
    record.id = object->get_string_throw("series");
    record.pid = object->get_integer_throw("pid");
    if (!valid_run_name(record.id) || record.pid <= 0) {
      return std::nullopt;
    }
    record.started_ms = object->get_integer_default("started_ms");
    record.result = object->get_string_default("result");
    record.run = object->get_string_default("run");
    record.runs = run_names(*object);
    record.json = trimmed(json);
    return record;
  } catch (const pa::Exception&) {  // bad JSON, a missing field
    return std::nullopt;
  }
}

std::optional<SeriesRecord> read_series_record(const std::string& registry,
                                               const std::string& id) {
  std::string text;
  if (!valid_run_name(id) ||
      !pa::file_to_string(
          series_dir(registry) + "/" + id + std::string(kSuffix), text)) {
    return std::nullopt;
  }
  auto record = parse_series_record(text);
  return record && record->id == id ? record : std::nullopt;
}

std::vector<SeriesRecord> live_series(
    const std::string& registry,
    const std::function<bool(std::int64_t)>& alive) {
  std::vector<SeriesRecord> series;
  std::vector<fs::Path> files;
  try {
    if (!fs::is_directory(series_dir(registry))) {
      return series;
    }
    files = fs::list_directory(series_dir(registry));
  } catch (const std::exception&) {
    return series;
  }
  for (const fs::Path& file : files) {
    const std::string name = file.string();
    std::string text;
    if (!name.ends_with(kSuffix) || !pa::file_to_string(name, text)) {
      continue;
    }
    const auto record = parse_series_record(text);
    if (record && record->result == "running" && alive(record->pid)) {
      series.push_back(*record);
    }
  }
  std::sort(series.begin(), series.end(),
            [](const SeriesRecord& a, const SeriesRecord& b) {
              return a.started_ms < b.started_ms;
            });
  return series;
}

std::string hub_series_json(const std::vector<SeriesRecord>& series) {
  std::string json = "[";
  for (const SeriesRecord& record : series) {
    if (json.size() > 1) {
      json += ",";
    }
    json += record.json;
  }
  return json + "]";
}

const SeriesRecord* series_of_run(const std::vector<SeriesRecord>& series,
                                  const std::string& run) {
  for (const SeriesRecord& record : series) {
    if (std::find(record.runs.begin(), record.runs.end(), run) !=
        record.runs.end()) {
      return &record;
    }
  }
  return nullptr;
}

}  // namespace gamepilot
