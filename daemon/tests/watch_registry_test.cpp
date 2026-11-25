// The watch registry and the hub: an entry is written while its daemon lives
// and removed after; readers skip stale entries (dead pid), other files and
// a missing folder; the hub's list keeps run folder paths off the network;
// a hub asked for port 0 gets a free one.

#include "watch_registry.h"

#include <functional>
#include <string>
#include <string_view>
#include <vector>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "check.h"
#include "net.h"
#include "page_assets.h"
#include "watch_assets.h"
#include "watch_hub.h"
#include "watch_server.h"

using namespace gamepilot;
namespace pa = PokemonAutomation;
namespace fs = pa::Filesystem;

namespace {

const std::string kDir =
    std::string(GAMEPILOT_TEST_OUTPUT_DIR) + "/watch_registry";

RegistryEntry entry(std::int64_t pid, const std::string& checkpoint) {
  return RegistryEntry{pid,
                       47950,
                       "127.0.0.1",
                       "mgba",
                       "/runs/2026-11-23-" + checkpoint + "-testing-1",
                       checkpoint,
                       1795435200000};
}

void check_entry_json() {
  const RegistryEntry written = entry(4242, "mg-02");
  const auto read = parse_registry_entry(registry_entry_json(written));
  CHECK(read && read->pid == 4242 && read->port == 47950 &&
        read->listen == "127.0.0.1" && read->backend == "mgba" &&
        read->run_folder == written.run_folder && read->checkpoint == "mg-02" &&
        read->started_ms == 1795435200000);
  // Our own runs write no name or source; a view-only source writes both.
  CHECK(registry_entry_json(written).find("\"name\"") == std::string::npos);
  CHECK(read && read->name.empty() && read->source.empty());
  RegistryEntry view = written;
  view.name = "pacc-maxlair-A";
  view.source = "pacc-window";
  const auto viewed = parse_registry_entry(registry_entry_json(view));
  CHECK(viewed && viewed->name == "pacc-maxlair-A" &&
        viewed->source == "pacc-window");
  for (const char* bad :
       {"", "not json", "[1]", "{\"port\":47950}", "{\"pid\":1}",
        "{\"pid\":1,\"port\":0}", "{\"pid\":0,\"port\":47950}",
        "{\"pid\":1,\"port\":70000}"}) {
    CHECK(!parse_registry_entry(bad));
  }
}

void check_entry_file() {
  fs::remove_all(kDir);
  CHECK(live_entries(kDir).empty());  // no folder yet
  std::string path;
  {
    const RegistryFile file(kDir, entry(own_pid(), "mg-01"));
    path = file.path();
    CHECK(fs::exists(path));
    // One JSON line as it is: no BOM, no CR (other readers parse it too).
    CHECK(fs::file_size(path) ==
          registry_entry_json(entry(own_pid(), "mg-01")).size() + 1);
    CHECK(path.ends_with("/" + std::to_string(own_pid()) + ".json"));
    const auto live = live_entries(kDir);
    CHECK(live.size() == 1 && live[0].pid == own_pid() &&
          live[0].checkpoint == "mg-01");
  }
  CHECK(!fs::exists(path));
  CHECK(live_entries(kDir).empty());
}

void check_stale_entries() {
  fs::remove_all(kDir);
  fs::create_directories(kDir);
  constexpr std::int64_t kDead = 999999001;  // no such process
  CHECK(process_alive(own_pid()));
  CHECK(!process_alive(kDead));
  CHECK(!process_alive(0));
  pa::string_to_file(kDir + "/" + std::to_string(kDead) + ".json",
                     registry_entry_json(entry(kDead, "mg-03")));
  pa::string_to_file(kDir + "/junk.json", "{");
  pa::string_to_file(kDir + "/notes.txt",
                     registry_entry_json(entry(own_pid(), "mg-09")));
  // Dead pids too: low pids like 5 and 7 are kernel threads on Linux.
  pa::string_to_file(kDir + "/1.json",
                     registry_entry_json(entry(kDead + 7, "b")));
  pa::string_to_file(kDir + "/2.json",
                     registry_entry_json(entry(kDead + 5, "a")));
  const RegistryFile own(kDir, entry(own_pid(), "mg-04"));

  const auto live = live_entries(kDir);
  CHECK(live.size() == 1 && live[0].checkpoint == "mg-04");

  // In pid order; `alive` decides what is stale.
  const auto all = live_entries(kDir, [](std::int64_t) { return true; });
  CHECK(all.size() == 4 && all[0].pid == own_pid() && all[1].pid == kDead &&
        all[2].pid == kDead + 5 && all[3].pid == kDead + 7);
}

void check_hub() {
  const std::string json = hub_runs_json({entry(12, "mg-05")});
  CHECK(json.find("\"run\":\"2026-11-23-mg-05-testing-1\"") !=
        std::string::npos);
  CHECK(json.find("/runs/") == std::string::npos);
  CHECK(json.find("\"port\":47950") != std::string::npos);
  CHECK(hub_runs_json({}) == "[]");
  RegistryEntry no_folder = entry(12, "mg-05");
  no_folder.run_folder.clear();
  CHECK(hub_run_name(no_folder) == "pid-12");

  // Newest first, keyed by the header; CRLF and a missing last field are fine.
  const std::string recent = hub_recent_json(
      "time\trun\tresult\r\nt1\tr1\tpass\r\nt2\tr2\tfail\r\nt3\tr3\n", 2);
  CHECK(recent ==
        "[{\"run\":\"r3\",\"time\":\"t3\"},"
        "{\"result\":\"fail\",\"run\":\"r2\",\"time\":\"t2\"}]");
  CHECK(hub_recent_json("", 2) == "[]");
  CHECK(hub_recent_json("time\trun\n", 2) == "[]");

  const WatchHub hub(HubOptions{"127.0.0.1", 0, kDir, "", ""});
  CHECK(hub.port() != 0);
  bool taken = false;
  try {
    const WatchHub second(HubOptions{"127.0.0.1", hub.port(), kDir, "", ""});
  } catch (const std::runtime_error&) {
    taken = true;
  }
  CHECK(taken);
}

// The hub and a run's page, served in turns until `want` came or the hub
// closed the connection.
std::string through_hub(WatchHub& hub, WatchServer& run, Socket& client,
                        const std::string& want) {
  std::string received;
  for (int round = 0; round < 100 && received.find(want) == std::string::npos;
       round++) {
    hub.serve_once(5);
    run.serve(poll_readable(run.sockets(), 5));
    if (poll_readable({&client}, 5)[0]) {
      const auto data = client.receive_some();
      if (!data) {
        break;
      }
      received += *data;
    }
  }
  return received;
}

std::string hub_request(WatchHub& hub, WatchServer& run,
                        const std::string& head, const std::string& want) {
  Socket client = connect_local(hub.port());
  client.send_all(head);
  return through_hub(hub, run, client, want);
}

// Each script and style `page` loads, served under `base` with its type
// (`get` asks the hub for a path, until the text it is given).
void check_assets(const std::function<std::string(const std::string&,
                                                  const std::string&)>& get,
                  const std::string& base, std::string_view page) {
  const std::vector<std::string> assets = test::page_assets(page);
  CHECK(assets.size() > 2);
  for (const std::string& name : assets) {
    const auto asset = watch_asset(name);
    CHECK(asset && asset->type == test::asset_type(name));
    if (!asset) {
      continue;
    }
    const std::string reply =
        get(base + name,
            std::string(asset->bytes.substr(asset->bytes.size() - 32)));
    CHECK(reply.starts_with("HTTP/1.1 200 OK"));
    CHECK(reply.find("Content-Type: " + std::string(asset->type) + "\r\n") !=
          std::string::npos);
    CHECK(reply.ends_with(asset->bytes));
  }
}

// A run's page under /runs/NAME/: the page with its token for this machine,
// its scripts and styles (and the hub's at /), Stop, the event stream as it
// comes, and /live's redirects.
void check_hub_pass_through() {
  fs::remove_all(kDir);
  int stops = 0;
  WatchServer run(WatchOptions{"127.0.0.1", 0, "t0"},
                  WatchHooks{[] { return WatchFrame{"image/png", "P"}; },
                             [&stops] {
                               stops++;
                               return true;
                             }});
  RegistryEntry own = entry(own_pid(), "mg-07");
  own.port = run.port();
  const RegistryFile file(kDir, own);
  WatchHub hub(HubOptions{"127.0.0.1", 0, kDir, "", ""});
  const std::string base = "/runs/2026-11-23-mg-07-testing-1/";

  const std::string page =
      hub_request(hub, run, "GET " + base + " HTTP/1.1\r\n\r\n", "</html>");
  CHECK(page.starts_with("HTTP/1.1 200 OK"));
  CHECK(page.find("content=\"t0\"") != std::string::npos);
  const auto get = [&](const std::string& path, const std::string& want) {
    return hub_request(hub, run, "GET " + path + " HTTP/1.1\r\n\r\n", want);
  };
  check_assets(get, base, watch_page());
  check_assets(get, "/", hub_page());
  CHECK(hub_request(hub, run,
                    "POST " + base + "stop?token=t0 HTTP/1.1\r\n\r\n", "}")
            .ends_with("{\"stopped\":true}"));
  CHECK(stops == 1);

  Socket viewer = connect_local(hub.port());
  viewer.send_all("GET " + base + "events HTTP/1.1\r\n\r\n");
  CHECK(through_hub(hub, run, viewer, "\r\n\r\n")
            .find("text/event-stream") != std::string::npos);
  run.add_log("{\"line\":\"one\"}");
  CHECK(through_hub(hub, run, viewer, "\"one\"").find("event: log") !=
        std::string::npos);

  const std::string moved = hub_request(
      hub, run, "GET /runs/2026-11-23-mg-07-testing-1?token=t0 HTTP/1.1\r\n\r\n",
      "\r\n\r\n");
  CHECK(moved.find("Location: " + base + "?token=t0\r\n") != std::string::npos);
  for (const std::string live : {"/live", "/live/", "/live/mg-07"}) {
    CHECK(hub_request(hub, run, "GET " + live + " HTTP/1.1\r\n\r\n",
                      "\r\n\r\n")
              .find("Location: " + base + "\r\n") != std::string::npos);
  }
  CHECK(hub_request(hub, run, "GET /live/mg-99 HTTP/1.1\r\n\r\n", "</html>")
            .starts_with("HTTP/1.1 404"));
  CHECK(hub_request(hub, run, "GET /runs/gone/ HTTP/1.1\r\n\r\n", "</html>")
            .find("is not live") != std::string::npos);
}

// A finished run's folder under /runs/NAME/: its page from the hub's build
// with its scripts and styles, its row, its files (never the wire log, never
// outside the folder), and the runs list.
void check_hub_past_run() {
  const std::string runs = kDir + "-runs";
  fs::remove_all(runs);
  const std::string folder = runs + "/2026-11-23-mg-06-testing-1";
  fs::create_directories(folder);
  {
    pa::FileIO log(folder + "/story.log",
                   pa::FileMode::WRITE | pa::FileMode::BINARY);
    log.write(std::string("[Story] mg-06: start, 1 events\n"));
    pa::FileIO wire(folder + "/wire.jsonl",
                    pa::FileMode::WRITE | pa::FileMode::BINARY);
    wire.write(std::string("{\"dir\":\"in\",\"msg\":{},\"t_ms\":5.0}\n"));
  }
  WatchServer idle(WatchOptions{"127.0.0.1", 0, ""},
                   WatchHooks{[] { return WatchFrame{}; }, [] { return false; }});
  WatchHub hub(HubOptions{"127.0.0.1", 0, runs + "/.watch", "", runs});
  const std::string base = "/runs/2026-11-23-mg-06-testing-1/";
  const auto get = [&](const std::string& path, const std::string& want) {
    return hub_request(hub, idle, "GET " + path + " HTTP/1.1\r\n\r\n", want);
  };
  CHECK(get(base, "</html>").find("GamePilot Run") != std::string::npos);
  check_assets(get, base, run_page());
  CHECK(get(base + "record.json", "}").find("\"checkpoint\":\"mg-06\"") !=
        std::string::npos);
  CHECK(get(base + "files/story.log", "events\n").ends_with("1 events\n"));
  CHECK(get(base + "files/wire.jsonl", "\n\n").starts_with("HTTP/1.1 404"));
  CHECK(get(base + "files/../../x", "\n\n").starts_with("HTTP/1.1 404"));
  CHECK(get("/runs/../x/", "\n\n").starts_with("HTTP/1.1 404"));
  CHECK(get(base + "probes.json", "}}").find("\"lines\":1") !=
        std::string::npos);
  CHECK(get(base + "events", "\n\n").starts_with("HTTP/1.1 404"));
  CHECK(get("/history.json", "]").find("2026-11-23-mg-06-testing-1") !=
        std::string::npos);
}

// A view-only source in the registry: listed under its name with its
// source, its page passed through, and never /live's newest run.
void check_hub_sources() {
  fs::remove_all(kDir);
  WatchServer source(WatchOptions{"127.0.0.1", 0, ""},
                     WatchHooks{[] { return WatchFrame{}; },
                                [] { return false; }});
  source.set_source("{\"state\":\"stale\",\"detail\":\"x\"}");
  RegistryEntry view = entry(own_pid(), "");
  view.port = source.port();
  view.backend = "view";
  view.run_folder.clear();
  view.name = "pacc-maxlair-A";
  view.source = "pacc-window";
  const RegistryFile file(kDir, view);
  WatchHub hub(HubOptions{"127.0.0.1", 0, kDir, "", ""});
  const auto get = [&](const std::string& path, const std::string& want) {
    return hub_request(hub, source, "GET " + path + " HTTP/1.1\r\n\r\n",
                       want);
  };
  const std::string runs = get("/runs.json", "]");
  CHECK(runs.find("\"run\":\"pacc-maxlair-A\"") != std::string::npos);
  CHECK(runs.find("\"source\":\"pacc-window\"") != std::string::npos);
  CHECK(get("/runs/pacc-maxlair-A/summary.json", "}}")
            .find("\"source\":{\"state\":\"stale\"") != std::string::npos);
  CHECK(get("/live", "</html>").starts_with("HTTP/1.1 404"));
}

}  // namespace

int main() {
  init_sockets();
  check_entry_json();
  check_entry_file();
  check_stale_entries();
  check_hub();
  check_hub_pass_through();
  check_hub_past_run();
  check_hub_sources();
  fs::remove_all(kDir);
  return TEST_RESULT();
}
