#include "run_history.h"

#include <algorithm>
#include <chrono>
#include <charconv>
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <ctime>
#include <initializer_list>
#include <iterator>
#include <system_error>
#include <utility>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "gzip_reader.h"
#include "rpc.h"

namespace gamepilot {

namespace {

namespace fs = pa::Filesystem;

constexpr std::string_view kModes[] = {"testing", "verification", "preflight",
                                       "single",  "run",          "bring-up"};
// The date at the start of a run folder's name: "2026-11-23-".
constexpr std::size_t kDatePrefix = 11;
// How much of a file's end is read for its last line.
constexpr std::int64_t kTailBytes = 64 * 1024;
// How much of wire.jsonl is read at once for the probe timeline.
constexpr std::size_t kChunkBytes = 1 << 20;
// How much of daemon.out is read for the backend.
constexpr std::size_t kHeadBytes = 512;
// Values are rounded to this many steps per unit before they are compared.
constexpr double kBrightnessSteps = 10;    // 0..255
constexpr double kFractionSteps = 1000;    // 0..1

std::string text_of(const std::string& path) {
  std::string text;
  if (!pa::file_to_string(path, text)) {
    return {};
  }
  return text;
}

std::string head_of(const std::string& path, std::size_t bytes) {
  pa::FileIO file;
  if (!file.open(path, pa::FileMode::READ | pa::FileMode::BINARY)) {
    return {};
  }
  std::string head(bytes, '\0');
  head.resize(file.read(head.data(), bytes));
  return head;
}

bool all_digits(std::string_view text) {
  return !text.empty() && std::all_of(text.begin(), text.end(), [](char c) {
    return c >= '0' && c <= '9';
  });
}

std::string string_field(const pa::JsonObject& object, const char* key) {
  return object.get_string_default(key, "");
}

// The backend from the daemon's first output line.
std::string backend_of_output(std::string_view out) {
  if (out.find("daemon: mgba") != std::string_view::npos) {
    return "mgba";
  }
  if (out.starts_with("board:") ||
      out.find("daemon: switch") != std::string_view::npos ||
      out.find("daemon: board") != std::string_view::npos) {
    return "switch";
  }
  return {};
}

// summary.txt's first word: PASS or FAIL.
std::string result_of_summary(std::string_view summary) {
  if (summary.starts_with("PASS")) {
    return "pass";
  }
  if (summary.starts_with("FAIL")) {
    return "fail";
  }
  return {};
}

void apply_run_json(RunRow& row, const pa::JsonObject& json) {
  for (const auto& [key, field] :
       std::initializer_list<std::pair<const char*, std::string RunRow::*>>{
           {"kind", &RunRow::kind},
           {"game", &RunRow::game},
           {"game_name", &RunRow::game_name},
           {"program", &RunRow::program},
           {"program_name", &RunRow::program_name},
           {"group", &RunRow::group},
           {"from", &RunRow::from},
           {"to", &RunRow::to},
           {"checkpoint", &RunRow::checkpoint},
           {"backend", &RunRow::backend},
           {"mode", &RunRow::mode},
           {"result", &RunRow::result},
           {"at", &RunRow::at},
           {"reason", &RunRow::reason}}) {
    const std::string value = string_field(json, key);
    if (!value.empty()) {
      row.*field = value;
    }
  }
  row.started_ms = json.get_integer_default("started_ms", row.started_ms);
  row.ended_ms = json.get_integer_default("ended_ms", row.ended_ms);
}

// One probe result as one number; none for a kind without one.
std::optional<double> probe_number(const pa::JsonObject& result) {
  const std::string kind = string_field(result, "kind");
  if (kind == "core.color_stats@1") {
    const pa::JsonArray* mean = result.get_array("mean");
    if (mean == nullptr || mean->size() != 3) {
      return std::nullopt;
    }
    double sum = 0;
    for (const pa::JsonValue& channel : *mean) {
      sum += channel.to_double_default(0);
    }
    return std::round(sum / 3 * kBrightnessSteps) / kBrightnessSteps;
  }
  const char* field = kind == "core.color_count@1"      ? "fraction"
                      : kind == "core.template_match@1" ? "score"
                                                        : nullptr;
  if (field == nullptr || result.get_value(field) == nullptr) {
    return std::nullopt;
  }
  return std::round(result.get_double_default(field, 0) * kFractionSteps) /
         kFractionSteps;
}

struct ProbeSeries {
  std::string kind;
  std::vector<std::pair<double, double>> points;  // kept: t_ms, value
  std::optional<std::pair<double, double>> pending;  // the bucket's last
  double bucket = -1;
};

void flush_bucket(ProbeSeries& series) {
  const bool changed =
      series.pending &&
      (series.points.empty() ||
       series.points.back().second != series.pending->second);
  if (changed) {
    series.points.push_back(*series.pending);
  }
  series.pending.reset();
}

// A wire log line's connection number (`conn`), none on a line without one
// (a log from before many clients, or the daemon's own).
std::optional<std::int64_t> line_conn(std::string_view text) {
  constexpr std::string_view kConn = "\"conn\":";
  const std::size_t at = text.find(kConn);
  std::int64_t conn = 0;
  if (at == std::string_view::npos ||
      std::from_chars(text.data() + at + kConn.size(),
                      text.data() + text.size(), conn)
              .ec != std::errc()) {
    return std::nullopt;
  }
  return conn;
}

class TimelineBuilder {
 public:
  explicit TimelineBuilder(double bucket_ms) : bucket_ms_(bucket_ms) {}

  void line(std::string_view text) {
    lines_++;
    if (!program_seen_ &&
        text.find("\"dir\":\"in\"") != std::string_view::npos) {
      program_seen_ = true;
      program_conn_ = line_conn(text);
    }
    const std::size_t t_at = text.rfind("\"t_ms\":");
    if (t_at != std::string_view::npos) {
      double t = 0;
      const char* begin = text.data() + t_at + 7;
      if (std::from_chars(begin, text.data() + text.size(), t).ec ==
          std::errc()) {
        t0_ = std::min(t0_, t);
        t1_ = std::max(t1_, t);
      }
    }
    // Only frames with results; most lines are frames with none.
    if (text.find("\"method\":\"frame\"") == std::string_view::npos ||
        text.find("\"probes\":{}") != std::string_view::npos ||
        (program_seen_ && line_conn(text) != program_conn_)) {
      return;
    }
    const pa::JsonValue value = pa::parse_json(std::string(text));
    const pa::JsonObject* line = value.to_object();
    const pa::JsonObject* message =
        line == nullptr ? nullptr : line->get_object("msg");
    const pa::JsonObject* params =
        message == nullptr ? nullptr : message->get_object("params");
    const pa::JsonObject* probes =
        params == nullptr ? nullptr : params->get_object("probes");
    if (probes == nullptr) {
      return;
    }
    const double t = line->get_double_default("t_ms", 0);
    const double bucket = std::floor(t / bucket_ms_);
    for (auto it = probes->begin(); it != probes->end(); ++it) {
      const pa::JsonObject* result = it->second.to_object();
      if (result == nullptr) {
        continue;
      }
      const auto number = probe_number(*result);
      if (!number) {
        continue;
      }
      ProbeSeries& series = series_[it->first];
      if (series.kind.empty()) {
        series.kind = string_field(*result, "kind");
      }
      if (series.bucket != bucket) {
        flush_bucket(series);
        series.bucket = bucket;
      }
      series.pending = std::make_pair(t, *number);
    }
  }

  std::string json() {
    pa::JsonObject probes;
    for (auto& [id, series] : series_) {
      flush_bucket(series);
      pa::JsonArray points;
      for (const auto& [t, v] : series.points) {
        pa::JsonArray point;
        point.push_back(std::round(t));
        point.push_back(v);
        points.push_back(std::move(point));
      }
      pa::JsonObject probe;
      probe["kind"] = series.kind;
      probe["points"] = std::move(points);
      probes[id] = std::move(probe);
    }
    pa::JsonObject out;
    out["bucket_ms"] = bucket_ms_;
    out["t0_ms"] = lines_ > 0 && t0_ <= t1_ ? t0_ : 0.0;
    out["t1_ms"] = lines_ > 0 && t0_ <= t1_ ? t1_ : 0.0;
    out["lines"] = lines_;
    out["probes"] = std::move(probes);
    return to_line(pa::JsonValue(std::move(out)));
  }

 private:
  double bucket_ms_;
  // The program's connection: that of the log's first `in` line.
  bool program_seen_ = false;
  std::optional<std::int64_t> program_conn_;
  std::int64_t lines_ = 0;
  double t0_ = 1e300;
  double t1_ = -1e300;
  std::map<std::string, ProbeSeries> series_;
};

// The start and end from the wire log where the notes gave none: with the
// clock's zero, its last line; else its span back from its last write (or
// from RESULTS.tsv's end).
void apply_wire_times(RunRow& row, const std::string& wire) {
  const double last = wire_log_end_ms(wire);
  if (last <= 0) {
    return;
  }
  if (row.started_ms > 0) {
    if (row.ended_ms == 0) {
      row.ended_ms = row.started_ms + static_cast<std::int64_t>(last);
    }
    return;
  }
  if (row.ended_ms > 0) {
    // RESULTS.tsv's end: back by how long the daemon ran.
    row.started_ms = row.ended_ms - static_cast<std::int64_t>(last);
    return;
  }
  // The log's last write is its last line; its first line came the log's
  // span before.
  row.ended_ms = mtime_ms(wire);
  if (row.ended_ms > 0) {
    row.started_ms = row.ended_ms - static_cast<std::int64_t>(
                                        last - wire_log_start_ms(wire));
  }
}

}  // namespace

bool valid_run_name(std::string_view name) {
  return !name.empty() && name.size() <= 200 && name[0] != '.' &&
         std::all_of(name.begin(), name.end(), [](char c) {
           return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
                  (c >= 'A' && c <= 'Z') || c == '-' || c == '_' || c == '.';
         });
}

std::optional<RunName> parse_run_name(std::string_view name) {
  if (name.size() <= kDatePrefix || name[4] != '-' || name[7] != '-' ||
      name[10] != '-' || !all_digits(name.substr(0, 4)) ||
      !all_digits(name.substr(5, 2)) || !all_digits(name.substr(8, 2))) {
    return std::nullopt;
  }
  std::string_view rest = name.substr(kDatePrefix);
  const std::size_t last = rest.rfind('-');
  if (last == std::string_view::npos || !all_digits(rest.substr(last + 1))) {
    return std::nullopt;
  }
  rest = rest.substr(0, last);
  for (const std::string_view mode : kModes) {
    const std::string suffix = "-" + std::string(mode);
    if (rest.size() > suffix.size() && rest.ends_with(suffix)) {
      return RunName{std::string(rest.substr(0, rest.size() - suffix.size())),
                     std::string(mode)};
    }
  }
  return std::nullopt;
}

ResultRows results_by_run(std::string_view results_tsv) {
  ResultRows rows;
  std::vector<std::string> columns;
  while (!results_tsv.empty()) {
    const std::size_t end = results_tsv.find('\n');
    std::string_view line = results_tsv.substr(0, end);
    results_tsv.remove_prefix(end == std::string_view::npos ? results_tsv.size()
                                                            : end + 1);
    if (!line.empty() && line.back() == '\r') {
      line.remove_suffix(1);
    }
    if (line.empty()) {
      continue;
    }
    std::vector<std::string> fields;
    while (true) {
      const std::size_t tab = line.find('\t');
      fields.emplace_back(line.substr(0, tab));
      if (tab == std::string_view::npos) {
        break;
      }
      line.remove_prefix(tab + 1);
    }
    if (columns.empty()) {
      columns = std::move(fields);
      continue;
    }
    std::map<std::string, std::string> row;
    for (std::size_t i = 0; i < columns.size() && i < fields.size(); i++) {
      row[columns[i]] = fields[i];
    }
    const auto run = row.find("run");
    if (run != row.end()) {
      rows[run->second] = std::move(row);  // a later row for a run wins
    }
  }
  return rows;
}

std::int64_t local_time_ms(std::string_view text) {
  // "YYYY-MM-DDTHH:MM:SS": each field at its place.
  constexpr std::size_t kLength = 19;
  constexpr std::pair<std::size_t, std::size_t> kFields[] = {
      {0, 4}, {5, 2}, {8, 2}, {11, 2}, {14, 2}, {17, 2}};
  if (text.size() < kLength || text[4] != '-' || text[7] != '-' ||
      text[10] != 'T' || text[13] != ':' || text[16] != ':') {
    return 0;
  }
  int values[6] = {};
  for (std::size_t i = 0; i < std::size(kFields); i++) {
    const std::string_view field =
        text.substr(kFields[i].first, kFields[i].second);
    if (!all_digits(field) ||
        std::from_chars(field.data(), field.data() + field.size(), values[i])
                .ec != std::errc()) {
      return 0;
    }
  }
  std::tm tm{};
  tm.tm_year = values[0] - 1900;
  tm.tm_mon = values[1] - 1;
  tm.tm_mday = values[2];
  tm.tm_hour = values[3];
  tm.tm_min = values[4];
  tm.tm_sec = values[5];
  tm.tm_isdst = -1;
  const std::time_t time = std::mktime(&tm);
  return time == static_cast<std::time_t>(-1)
             ? 0
             : static_cast<std::int64_t>(time) * 1000;
}

double wire_log_end_ms(const std::string& path) {
  pa::FileIO file;
  if (!file.open(path, pa::FileMode::READ | pa::FileMode::BINARY) ||
      !file.seek(0, SEEK_END)) {
    return 0;
  }
  const std::int64_t size = file.tell();
  const std::int64_t from = std::max<std::int64_t>(0, size - kTailBytes);
  if (size <= 0 || !file.seek(from, SEEK_SET)) {
    return 0;
  }
  std::string tail(static_cast<std::size_t>(size - from), '\0');
  tail.resize(file.read(tail.data(), tail.size()));
  const std::size_t at = tail.rfind("\"t_ms\":");
  double t = 0;
  if (at == std::string::npos ||
      std::from_chars(tail.data() + at + 7, tail.data() + tail.size(), t).ec !=
          std::errc()) {
    return 0;
  }
  return t;
}

double wire_log_start_ms(const std::string& path) {
  const std::string head = head_of(path, kHeadBytes);
  const std::size_t line_end = head.find('\n');
  const std::string_view line = std::string_view(head).substr(0, line_end);
  const std::size_t at = line.rfind("\"t_ms\":");
  double t = 0;
  if (at == std::string_view::npos ||
      std::from_chars(line.data() + at + 7, line.data() + line.size(), t).ec !=
          std::errc()) {
    return 0;
  }
  return t;
}

std::int64_t mtime_ms(const std::string& path) {
  std::error_code error;
  const auto time =
      std::filesystem::last_write_time(pa::Filesystem::Path(path).stdpath(), error);
  if (error) {
    return 0;
  }
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::file_clock::to_sys(time).time_since_epoch())
      .count();
}

RunRow read_run(const std::string& runs_dir, const std::string& name,
                const ResultRows& results) {
  const std::string dir = runs_dir + "/" + name;
  RunRow row;
  row.run = name;
  if (const auto parsed = parse_run_name(name)) {
    row.checkpoint = parsed->checkpoint;
    row.mode = parsed->mode;
  }
  const auto result = results.find(name);
  if (result != results.end()) {
    const auto field = [&](const char* key) {
      const auto it = result->second.find(key);
      return it == result->second.end() ? std::string() : it->second;
    };
    row.result = field("result");
    row.at = field("at");
    row.reason = field("reason");
    if (!field("checkpoint").empty()) {
      row.checkpoint = field("checkpoint");
    }
    if (!field("mode").empty()) {
      row.mode = field("mode");
    }
    row.ended_ms = local_time_ms(field("time"));
  }
  if (row.result.empty()) {
    row.result = result_of_summary(text_of(dir + "/summary.txt"));
  }
  const pa::JsonValue daemon = pa::parse_json(text_of(dir + "/daemon.json"));
  if (const pa::JsonObject* object = daemon.to_object()) {
    row.backend = string_field(*object, "backend");
    row.started_ms = static_cast<std::int64_t>(
        object->get_double_default("clock_zero_unix_ms", 0));
  }
  if (row.backend.empty()) {
    row.backend = backend_of_output(head_of(dir + "/daemon.out", kHeadBytes));
  }
  apply_wire_times(row, dir + "/wire.jsonl");
  const pa::JsonValue run = pa::parse_json(text_of(dir + "/run.json"));
  if (const pa::JsonObject* object = run.to_object()) {
    apply_run_json(row, *object);
  }
  if (row.started_ms == 0) {
    row.started_ms = mtime_ms(dir);
  }
  if (row.kind.empty()) {
    row.kind = row.mode == "preflight"  ? "preflight"
               : row.checkpoint.empty() ? "daemon"
                                        : "checkpoints";
  }
  if (row.result.empty()) {
    row.result = "unknown";
  }
  if (row.from.empty()) {
    row.from = row.checkpoint;
    row.to = row.checkpoint;
  }
  row.recorded = fs::exists(dir + "/frames/index.jsonl");
  row.failure_frame = fs::exists(dir + "/failure.png");
  return row;
}

std::vector<RunRow> list_runs(const std::string& runs_dir,
                              std::string_view results_tsv,
                              const std::set<std::string>& live) {
  std::vector<RunRow> rows;
  std::vector<fs::Path> entries;
  try {
    entries = fs::list_directory(runs_dir);
  } catch (const std::exception&) {
    return rows;
  }
  const ResultRows results = results_by_run(results_tsv);
  for (const fs::Path& entry : entries) {
    const std::string name = entry.filename().string();
    if (!valid_run_name(name) || !fs::is_directory(entry)) {
      continue;
    }
    RunRow row = read_run(runs_dir, name, results);
    if (live.contains(name)) {
      row.live = true;
      row.result = "running";
      row.ended_ms = 0;
    }
    rows.push_back(std::move(row));
  }
  // Newest first (every row has a start: read_run's fallbacks end at the
  // folder's mtime); the name breaks ties.
  std::sort(rows.begin(), rows.end(), [](const RunRow& a, const RunRow& b) {
    if (a.started_ms != b.started_ms) {
      return a.started_ms > b.started_ms;
    }
    return a.run > b.run;
  });
  return rows;
}

std::string run_row_json(const RunRow& row) {
  pa::JsonObject json;
  json["run"] = row.run;
  json["kind"] = row.kind;
  json["game"] = row.game;
  json["game_name"] = row.game_name;
  json["program"] = row.program;
  json["program_name"] = row.program_name;
  json["group"] = row.group;
  json["from"] = row.from;
  json["to"] = row.to;
  json["checkpoint"] = row.checkpoint;
  json["backend"] = row.backend;
  json["mode"] = row.mode;
  json["result"] = row.result;
  json["at"] = row.at;
  json["reason"] = row.reason;
  json["started_ms"] = row.started_ms;
  json["ended_ms"] = row.ended_ms;
  json["live"] = row.live;
  json["recorded"] = row.recorded;
  json["failure_frame"] = row.failure_frame;
  return to_line(pa::JsonValue(std::move(json)));
}

std::string run_rows_json(const std::vector<RunRow>& rows) {
  std::string out = "[";
  for (std::size_t i = 0; i < rows.size(); i++) {
    if (i > 0) {
      out += ",";
    }
    out += run_row_json(rows[i]);
  }
  return out + "]";
}

bool servable_run_file(std::string_view path) {
  for (const std::string_view name :
       {"run.json", "daemon.json", "watch_plan.json", "watch_run.json",
        "watch_log.jsonl", "story.log", "summary.txt", "failure.png",
        "frames/index.jsonl"}) {
    if (path == name) {
      return true;
    }
  }
  constexpr std::string_view kFrames = "frames/";
  constexpr std::string_view kJpeg = ".jpg";
  return path.starts_with(kFrames) && path.ends_with(kJpeg) &&
         all_digits(path.substr(kFrames.size(), path.size() - kFrames.size() -
                                                    kJpeg.size()));
}

std::string_view run_file_type(std::string_view path) {
  if (path.ends_with(".jpg")) {
    return "image/jpeg";
  }
  if (path.ends_with(".png")) {
    return "image/png";
  }
  if (path.ends_with(".json")) {
    return "application/json";
  }
  return "text/plain; charset=utf-8";
}

std::string probe_timeline_json(const std::string& wire_log, double bucket_ms) {
  TimelineBuilder builder(bucket_ms);
  pa::FileIO file;
  GzipReader gzip;
  const bool gzipped = wire_log.ends_with(".gz");
  const bool opened =
      gzipped ? gzip.open(wire_log)
              : file.open(wire_log, pa::FileMode::READ | pa::FileMode::BINARY);
  if (opened) {
    std::string buffer;
    std::string chunk(kChunkBytes, '\0');
    while (true) {
      const std::size_t n = gzipped ? gzip.read(chunk.data(), chunk.size())
                                    : file.read(chunk.data(), chunk.size());
      buffer.append(chunk.data(), n);
      std::size_t start = 0;
      while (true) {
        const std::size_t end = buffer.find('\n', start);
        if (end == std::string::npos) {
          break;
        }
        if (end > start) {
          builder.line(std::string_view(buffer).substr(start, end - start));
        }
        start = end + 1;
      }
      buffer.erase(0, start);
      if (n < chunk.size()) {
        break;
      }
    }
    if (!buffer.empty()) {
      builder.line(buffer);
    }
  }
  return builder.json();
}

}  // namespace gamepilot
