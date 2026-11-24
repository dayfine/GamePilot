// The runs folder as the hub reads it (run_history.h) and the daemon's notes
// (run_journal.h): each case a name, its input and what is expected.

#include "run_history.h"

#include <cstdio>
#include <optional>
#include <string>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "check.h"
#include "rpc.h"
#include "run_journal.h"

#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#include "miniz-3.1.1/miniz.h"

using namespace gamepilot;
namespace fs = pa::Filesystem;

namespace {

const std::string kDir =
    std::string(GAMEPILOT_TEST_OUTPUT_DIR) + "/run_history";

void write(const std::string& path, const std::string& text) {
  pa::FileIO file(path, pa::FileMode::WRITE | pa::FileMode::BINARY);
  file.write(text);
}

void check_run_names() {
  struct Case {
    std::string name;
    std::string input;
    std::optional<RunName> expect;
  };
  const std::vector<Case> cases = {
      {"testing", "2026-11-23-mg-07-testing-1", RunName{"mg-07", "testing"}},
      {"verification, a letter in the id", "2026-11-23-mg-05a-verification-12",
       RunName{"mg-05a", "verification"}},
      {"a hand-made folder", "2026-11-23-switch-idle", std::nullopt},
      {"no number", "2026-11-23-mg-07-testing", std::nullopt},
      {"no date", "mg-07-testing-1", std::nullopt},
      {"no checkpoint", "2026-11-23-testing-1", std::nullopt},
      {"a pre-flight", "2026-11-23-mg-01-preflight-1",
       RunName{"mg-01", "preflight"}},
      {"the bring-up checks", "2026-11-23-switch-bring-up-2",
       RunName{"switch", "bring-up"}},
      {"one checkpoint", "2026-11-23-mg-04-single-1",
       RunName{"mg-04", "single"}},
      {"a one-shot program", "2026-11-23-frlg.start_menu_poc-run-1",
       RunName{"frlg.start_menu_poc", "run"}},
  };
  for (const Case& c : cases) {
    if (parse_run_name(c.input) != c.expect) {
      std::fprintf(stderr, "parse_run_name: %s\n", c.name.c_str());
    }
    CHECK(parse_run_name(c.input) == c.expect);
  }
}

void check_names_and_files() {
  struct Case {
    std::string input;
    bool run_name;
    bool servable;
  };
  const std::vector<Case> cases = {
      {"2026-11-23-mg-07-testing-1", true, false},
      {".watch", false, false},
      {"../etc", false, false},
      {"a/b", false, false},
      {"", false, false},
      {"story.log", true, true},
      {"failure.png", true, true},
      {"watch_plan.json", true, true},
      {"frames/index.jsonl", false, true},
      {"frames/000012.jpg", false, true},
      {"frames/../wire.jsonl", false, false},
      {"frames/x.jpg", false, false},
      {"wire.jsonl", true, false},
      {"daemon.out", true, false},
      {"end.ss", true, false},
  };
  for (const Case& c : cases) {
    CHECK(valid_run_name(c.input) == c.run_name);
    CHECK(servable_run_file(c.input) == c.servable);
  }
  CHECK(run_file_type("frames/000001.jpg") == "image/jpeg");
  CHECK(run_file_type("failure.png") == "image/png");
  CHECK(run_file_type("story.log").starts_with("text/plain"));
}

void check_results() {
  const ResultRows rows = results_by_run(
      "time\trun\tcheckpoint\tmode\tresult\tat\treason\r\n"
      "2026-11-23T12:50:03\tr1\tmg-04\ttesting\tfail\t#2 x\tno_text\r\n"
      "2026-11-23T12:53:24\tr1\tmg-04\ttesting\tpass\t\t\n"
      "2026-11-23T12:55:00\tr2\tmg-05\ttesting\tpass\n");
  CHECK(rows.size() == 2);
  CHECK(rows.at("r1").at("result") == "pass");  // the later row wins
  CHECK(rows.at("r2").at("checkpoint") == "mg-05");
  CHECK(!rows.at("r2").contains("reason"));
  CHECK(results_by_run("").empty());
  CHECK(local_time_ms("2026-11-23T12:53:24") -
            local_time_ms("2026-11-23T12:50:03") ==
        201000);
  CHECK(local_time_ms("yesterday") == 0);
}

// A folder from before run.json: its name, RESULTS.tsv, the daemon's first
// line and the wire log's last time. A new one: run.json and daemon.json.
void check_read_run() {
  fs::remove_all(kDir);
  const std::string old_run = kDir + "/2026-11-23-mg-04-testing-2";
  fs::create_directories(old_run);
  write(old_run + "/daemon.out", "daemon: mgba bridge on 47810, game BPRE\n");
  write(old_run + "/wire.jsonl",
        "{\"dir\":\"in\",\"msg\":{},\"t_ms\":10.0}\n"
        "{\"dir\":\"out\",\"msg\":{},\"t_ms\":65000.5}\n");
  write(old_run + "/failure.png", "png");
  const std::string tsv =
      "time\trun\tcheckpoint\tmode\tresult\tat\treason\n"
      "2026-11-23T12:50:05\t2026-11-23-mg-04-testing-2\tmg-04\ttesting\tfail"
      "\t#2 talk\tno_text\n";
  const RunRow old_row =
      read_run(kDir, "2026-11-23-mg-04-testing-2", results_by_run(tsv));
  CHECK(old_row.checkpoint == "mg-04" && old_row.mode == "testing");
  CHECK(old_row.from == "mg-04" && old_row.to == "mg-04");
  CHECK(old_row.backend == "mgba");
  CHECK(old_row.result == "fail" && old_row.at == "#2 talk" &&
        old_row.reason == "no_text");
  CHECK(old_row.ended_ms == local_time_ms("2026-11-23T12:50:05"));
  CHECK(old_row.started_ms == old_row.ended_ms - 65000);
  CHECK(old_row.game.empty() && old_row.failure_frame && !old_row.recorded);

  // A backfilled run.json (gamepilot runs --backfill) names the program only:
  // the result and times still come from the fallbacks.
  write(old_run + "/run.json",
        "{\"run\":\"2026-11-23-mg-04-testing-2\",\"game\":\"frlg\","
        "\"game_name\":\"FRLG\",\"program\":\"frlg.mail_glitch\","
        "\"program_name\":\"Mail Glitch\",\"group\":\"FRLG / Glitches\","
        "\"checkpoint\":\"mg-04\",\"mode\":\"testing\","
        "\"backfilled\":true}\n");
  const RunRow backfilled =
      read_run(kDir, "2026-11-23-mg-04-testing-2", results_by_run(tsv));
  CHECK(backfilled.program == "frlg.mail_glitch" &&
        backfilled.program_name == "Mail Glitch" &&
        backfilled.game_name == "FRLG" &&
        backfilled.group == "FRLG / Glitches");
  CHECK(backfilled.result == old_row.result &&
        backfilled.started_ms == old_row.started_ms &&
        backfilled.ended_ms == old_row.ended_ms);
  fs::remove(old_run + "/run.json");

  const std::string new_run = kDir + "/2026-11-23-mg-07-testing-1";
  fs::create_directories(new_run + "/frames");
  write(new_run + "/run.json",
        "{\"run\":\"2026-11-23-mg-07-testing-1\",\"game\":\"frlg\","
        "\"program\":\"mail_glitch\",\"from\":\"mg-05\",\"to\":\"mg-08\","
        "\"checkpoint\":\"mg-07\",\"backend\":\"switch\",\"mode\":\"testing\","
        "\"started_ms\":1795500000000,\"ended_ms\":1795500060000,"
        "\"result\":\"pass\",\"at\":\"\",\"reason\":\"\"}\n");
  write(new_run + "/frames/index.jsonl", "{}\n");
  const RunRow new_row = read_run(kDir, "2026-11-23-mg-07-testing-1", {});
  CHECK(new_row.game == "frlg" && new_row.program == "mail_glitch");
  CHECK(new_row.from == "mg-05" && new_row.to == "mg-08" &&
        new_row.checkpoint == "mg-07");
  CHECK(new_row.backend == "switch" && new_row.result == "pass");
  CHECK(new_row.started_ms == 1795500000000 &&
        new_row.ended_ms == 1795500060000);
  CHECK(new_row.recorded && !new_row.failure_frame);

  const auto rows = list_runs(kDir, tsv, {"2026-11-23-mg-07-testing-1"});
  CHECK(rows.size() == 2);
  CHECK(rows[0].run == "2026-11-23-mg-07-testing-1" && rows[0].live &&
        rows[0].result == "running");
  CHECK(run_rows_json({}) == "[]");
}

// Folders with no run.json: a start from daemon.json, else the wire log's
// first line, else the folder's mtime; an end from the wire log's last line;
// result "unknown"; and they sort by that start, never all at the bottom.
void check_fallbacks() {
  const std::string dir = kDir + "/fallbacks";
  fs::remove_all(dir);
  const std::string wire_lines =
      "{\"dir\":\"in\",\"msg\":{},\"t_ms\":1000.0}\n"
      "{\"dir\":\"out\",\"msg\":{},\"t_ms\":61000.0}\n";
  struct Case {
    std::string name;  // also the folder's
    bool daemon_json;
    bool wire;
    std::string kind;
  };
  const std::vector<Case> cases = {
      {"2026-11-23-switch-idle", true, true, "daemon"},
      {"2026-11-23-switch-bringup-poc", false, true, "daemon"},
      {"2026-11-23-mg-01-preflight-1", true, false, "preflight"},
      {"2026-11-23-empty", false, false, "daemon"},
  };
  for (const Case& c : cases) {
    const std::string folder = dir + "/" + c.name;
    fs::create_directories(folder);
    if (c.daemon_json) {
      write(folder + "/daemon.json",
            "{\"backend\":\"switch\",\"clock_zero_unix_ms\":1795500000000}\n");
    }
    if (c.wire) {
      write(folder + "/wire.jsonl", wire_lines);
    }
  }
  for (const Case& c : cases) {
    const std::string folder = dir + "/" + c.name;
    const RunRow row = read_run(dir, c.name, {});
    const std::int64_t wire_written = mtime_ms(folder + "/wire.jsonl");
    const std::int64_t start = c.daemon_json ? 1795500000000
                               : c.wire      ? wire_written - 60000
                                             : mtime_ms(folder);
    const std::int64_t end = c.daemon_json && c.wire ? 1795500061000
                             : c.wire                ? wire_written
                                                     : 0;
    if (row.started_ms != start || row.ended_ms != end ||
        row.result != "unknown" || row.kind != c.kind) {
      std::fprintf(stderr, "read_run fallbacks: %s\n", c.name.c_str());
    }
    CHECK(start > 0);
    CHECK(row.started_ms == start);
    CHECK(row.ended_ms == end);
    CHECK(row.result == "unknown");
    CHECK(row.kind == c.kind);
  }
  // Newest first by start: the empty folder (made now) above the old ones.
  const auto rows = list_runs(dir, "", {});
  CHECK(rows.size() == cases.size());
  CHECK(rows[0].run == "2026-11-23-empty" ||
        rows[0].run == "2026-11-23-switch-bringup-poc");
  for (std::size_t i = 1; i < rows.size(); i++) {
    CHECK(rows[i - 1].started_ms >= rows[i].started_ms);
  }
}

// One value a probe a second, the bucket's last, kept only when it changed;
// frames without results and unknown kinds are skipped.
void check_probe_timeline() {
  fs::create_directories(kDir);
  const std::string wire = kDir + "/timeline.jsonl";
  const auto frame = [](double t, const std::string& probes) {
    return "{\"dir\":\"out\",\"msg\":{\"jsonrpc\":\"2.0\",\"method\":\"frame\","
           "\"params\":{\"load\":1,\"probes\":{" +
           probes + "},\"seq\":1,\"t_ms\":0}},\"t_ms\":" + std::to_string(t) +
           "}\n";
  };
  const std::string fade = [] {
    return std::string("\"fade\":{\"kind\":\"core.color_stats@1\","
                       "\"mean\":[30,30,30],\"stddev\":[1,1,1]}");
  }();
  write(wire,
        frame(100, fade) +
            frame(600, "\"fade\":{\"kind\":\"core.color_stats@1\",\"mean\":"
                       "[60,60,60],\"stddev\":[1,1,1]}") +
            frame(1200, "\"fade\":{\"kind\":\"core.color_stats@1\",\"mean\":"
                        "[60,60,60],\"stddev\":[1,1,1]}") +
            frame(1500, "") +
            frame(2100, "\"arrow\":{\"kind\":\"core.color_count@1\","
                        "\"fraction\":0.12345,\"mean\":null},\"ocr\":{\"kind\":"
                        "\"core.ocr@1\",\"text\":\"x\"}") +
            "{\"dir\":\"in\",\"msg\":{},\"t_ms\":2500.0}\n");
  const pa::JsonValue json =
      pa::parse_json(probe_timeline_json(wire, 1000));
  const pa::JsonObject* out = json.to_object();
  CHECK(out != nullptr);
  if (out == nullptr) {
    return;
  }
  CHECK(out->get_integer_default("lines", 0) == 6);
  CHECK(out->get_double_default("t0_ms", 0) == 100);
  CHECK(out->get_double_default("t1_ms", 0) == 2500);
  const pa::JsonObject* probes = out->get_object("probes");
  CHECK(probes != nullptr && probes->size() == 2);  // not the ocr one
  if (probes == nullptr) {
    return;
  }
  // fade: 60 at 600 ms (the first second's last), then unchanged.
  CHECK(to_line(probes->get_value_throw("fade")) ==
        "{\"kind\":\"core.color_stats@1\",\"points\":[[600.0,60.0]]}");
  CHECK(to_line(probes->get_value_throw("arrow")) ==
        "{\"kind\":\"core.color_count@1\",\"points\":[[2100.0,0.123]]}");
  CHECK(probe_timeline_json(kDir + "/none.jsonl", 1000).find("\"lines\":0") !=
        std::string::npos);
}

// `text` as a gzip file (RFC 1952 header, raw deflate, CRC-32 and size).
std::string gzip(const std::string& text) {
  mz_stream stream{};
  CHECK(mz_deflateInit2(&stream, MZ_DEFAULT_COMPRESSION, MZ_DEFLATED,
                        -MZ_DEFAULT_WINDOW_BITS, 9,
                        MZ_DEFAULT_STRATEGY) == MZ_OK);
  std::string body(
      mz_deflateBound(&stream, static_cast<mz_ulong>(text.size())), '\0');
  stream.next_in = reinterpret_cast<const unsigned char*>(text.data());
  stream.avail_in = static_cast<unsigned int>(text.size());
  stream.next_out = reinterpret_cast<unsigned char*>(body.data());
  stream.avail_out = static_cast<unsigned int>(body.size());
  CHECK(mz_deflate(&stream, MZ_FINISH) == MZ_STREAM_END);
  body.resize(stream.total_out);
  mz_deflateEnd(&stream);
  // Magic, deflate, FNAME set, mtime, flags, OS; then the name.
  std::string out("\x1f\x8b\x08\x08\0\0\0\0\0\x03wire.jsonl", 20);
  out.push_back('\0');
  out += body;
  const auto le32 = [&](std::uint32_t v) {
    for (int i = 0; i < 4; i++) {
      out.push_back(static_cast<char>((v >> (8 * i)) & 0xff));
    }
  };
  le32(static_cast<std::uint32_t>(mz_crc32(
      MZ_CRC32_INIT, reinterpret_cast<const unsigned char*>(text.data()),
      text.size())));
  le32(static_cast<std::uint32_t>(text.size()));
  return out;
}

// A packed wire log reads as the plain one; only the program's connection
// (the first to speak) counts.
void check_packed_timeline_of_the_program() {
  fs::create_directories(kDir);
  const auto frame = [](int conn, double t, int mean) {
    return "{\"conn\":" + std::to_string(conn) +
           ",\"dir\":\"out\",\"msg\":{\"jsonrpc\":\"2.0\",\"method\":"
           "\"frame\",\"params\":{\"load\":0,\"probes\":{\"fade\":{\"kind\":"
           "\"core.color_stats@1\",\"mean\":[" +
           std::to_string(mean) + "," + std::to_string(mean) + "," +
           std::to_string(mean) +
           "],\"stddev\":[1,1,1]}},\"seq\":1,\"t_ms\":0}},\"t_ms\":" +
           std::to_string(t) + "}\n";
  };
  std::string text = "{\"conn\":1,\"dir\":\"in\",\"msg\":{},\"t_ms\":1.0}\n";
  // Many lines, so the packed stream spans several input chunks.
  for (int i = 0; i < 20000; i++) {
    text += frame(1, 100 + i * 10, 30 + (i / 1000));
    text += frame(2, 105 + i * 10, 200);
  }
  write(kDir + "/wire.jsonl.gz", gzip(text));
  write(kDir + "/wire.jsonl", text);
  const std::string packed = probe_timeline_json(kDir + "/wire.jsonl.gz", 1000);
  CHECK(packed == probe_timeline_json(kDir + "/wire.jsonl", 1000));
  CHECK(packed.find("\"lines\":40001") != std::string::npos);
  CHECK(packed.find("200.0") == std::string::npos);  // connection 2's frames
  CHECK(packed.find("[990.0,30.0]") != std::string::npos);
  write(kDir + "/bad.jsonl.gz", "not gzip");
  CHECK(probe_timeline_json(kDir + "/bad.jsonl.gz", 1000).find("\"lines\":0") !=
        std::string::npos);
}

void check_current_step() {
  struct Case {
    std::string name;
    std::string plan;
    PlanStep expect;
  };
  const std::vector<Case> cases = {
      {"the current event",
       "{\"events\":[{\"id\":\"a\",\"state\":\"done\"},"
       "{\"id\":\"b\",\"state\":\"current\"},{\"id\":\"c\",\"state\":"
       "\"pending\"}]}",
       {"b", false}},
      {"a failed event",
       "{\"events\":[{\"id\":\"a\",\"state\":\"done\"},"
       "{\"id\":\"b\",\"state\":\"failed\"}]}",
       {"b", true}},
      {"between two events: none",
       "{\"events\":[{\"id\":\"a\",\"state\":\"done\"},"
       "{\"id\":\"b\",\"state\":\"pending\"}]}",
       {}},
      {"no events", "{}", {}},
  };
  for (const Case& c : cases) {
    const PlanStep step =
        current_step(*pa::parse_json(c.plan).to_object());
    if (!(step == c.expect)) {
      std::fprintf(stderr, "current_step: %s\n", c.name.c_str());
    }
    CHECK(step == c.expect);
  }
}

// The daemon's notes: daemon.json at once, the plan and chain rewritten,
// each story line appended with its time.
void check_journal() {
  const std::string folder = kDir + "/journal";
  fs::remove_all(folder);
  fs::create_directories(folder);
  {
    RunJournal journal(folder,
                       DaemonRecord{"switch", 1795500000000, true, 180});
    journal.plan("{\"events\":[]}");
    journal.plan("{\"events\":[1]}");
    journal.log_line(*pa::parse_json("{\"line\":\"[Story] a\"}").to_object(),
                     1795500001000);
    journal.log_line(*pa::parse_json("{\"line\":\"b\"}").to_object(),
                     1795500002000);
  }
  CHECK(pa::file_to_string(folder + "/daemon.json") ==
        "{\"backend\":\"switch\",\"clock_zero_unix_ms\":1795500000000,"
        "\"keepawake_s\":180.0,\"record\":true}\n");
  CHECK(pa::file_to_string(folder + "/watch_plan.json") ==
        "{\"events\":[1]}\n");
  CHECK(pa::file_to_string(folder + "/watch_log.jsonl") ==
        "{\"line\":\"[Story] a\",\"unix_ms\":1795500001000}\n"
        "{\"line\":\"b\",\"unix_ms\":1795500002000}\n");
}

// A daemon started by hand writes run.json (kind daemon) and its end; one a
// runner started keeps the runner's run.json as it is.
void check_journal_run_json() {
  const DaemonRecord record{"switch", 1795500000000, false, 180};
  struct Case {
    std::string name;
    std::string existing;  // run.json before the daemon; empty for none
    std::string expect_prefix;  // run.json after it stopped
  };
  const std::vector<Case> cases = {
      {"by-hand", "",
       "{\"backend\":\"switch\",\"checkpoint\":\"idle\",\"ended_ms\":"},
      {"runner", "{\"run\":\"runner\",\"kind\":\"checkpoints\"}\n",
       "{\"run\":\"runner\",\"kind\":\"checkpoints\"}\n"},
  };
  for (const Case& c : cases) {
    const std::string folder = kDir + "/journal-" + c.name;
    fs::remove_all(folder);
    fs::create_directories(folder);
    if (!c.existing.empty()) {
      write(folder + "/run.json", c.existing);
    }
    {
      RunJournal journal(folder, record, "idle");
      if (c.existing.empty()) {
        CHECK(pa::file_to_string(folder + "/run.json") ==
              daemon_run_json("journal-by-hand", record, "idle", 0) + "\n");
      }
    }
    const std::string after = pa::file_to_string(folder + "/run.json");
    if (!after.starts_with(c.expect_prefix)) {
      std::fprintf(stderr, "journal run.json: %s: %s\n", c.name.c_str(),
                   after.c_str());
    }
    CHECK(after.starts_with(c.expect_prefix));
  }
  CHECK(daemon_run_json("r", record, "idle", 0) ==
        "{\"backend\":\"switch\",\"checkpoint\":\"idle\",\"kind\":"
        "\"daemon\",\"run\":\"r\",\"started_ms\":1795500000000}");
}

}  // namespace

int main() {
  check_run_names();
  check_names_and_files();
  check_results();
  check_read_run();
  check_fallbacks();
  check_probe_timeline();
  check_packed_timeline_of_the_program();
  check_current_step();
  check_journal();
  check_journal_run_json();
  return TEST_RESULT();
}
