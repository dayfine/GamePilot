#include "watch_registry.h"

#include <algorithm>
#include <chrono>
#include <exception>
#include <stdexcept>
#include <string_view>

#include "Common/Cpp/Exceptions.h"
#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "rpc.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <signal.h>
#include <unistd.h>

#include <cerrno>
#endif

namespace gamepilot {

namespace fs = pa::Filesystem;

namespace {

constexpr std::string_view kSuffix = ".json";

// As it is: pa::string_to_file adds a BOM and CRLFs, which other readers
// (`gamepilot runs`) would have to strip.
void write_file(const std::string& path, const std::string& text) {
  pa::FileIO file;
  if (!file.open(path, pa::FileMode::WRITE | pa::FileMode::BINARY) ||
      file.write(text) != text.size()) {
    throw std::runtime_error("cannot write " + path);
  }
}

}  // namespace

std::string registry_entry_json(const RegistryEntry& entry) {
  pa::JsonObject json;
  json["pid"] = entry.pid;
  json["port"] = static_cast<std::int64_t>(entry.port);
  json["listen"] = entry.listen;
  json["backend"] = entry.backend;
  json["run_folder"] = entry.run_folder;
  json["checkpoint"] = entry.checkpoint;
  json["started_ms"] = entry.started_ms;
  if (!entry.name.empty()) {
    json["name"] = entry.name;
  }
  if (!entry.source.empty()) {
    json["source"] = entry.source;
  }
  return to_line(pa::JsonValue(std::move(json)));
}

std::optional<RegistryEntry> parse_registry_entry(const std::string& json) {
  try {
    const pa::JsonValue value = pa::parse_json(json);
    const pa::JsonObject* object = value.to_object();
    if (object == nullptr) {
      return std::nullopt;
    }
    RegistryEntry entry;
    entry.pid = object->get_integer_throw("pid");
    const std::int64_t port = object->get_integer_throw("port");
    if (entry.pid <= 0 || port <= 0 || port > 65535) {
      return std::nullopt;
    }
    entry.port = static_cast<std::uint16_t>(port);
    entry.listen = object->get_string_default("listen", "127.0.0.1");
    entry.backend = object->get_string_default("backend");
    entry.run_folder = object->get_string_default("run_folder");
    entry.checkpoint = object->get_string_default("checkpoint");
    entry.started_ms = object->get_integer_default("started_ms");
    entry.name = object->get_string_default("name");
    entry.source = object->get_string_default("source");
    return entry;
  } catch (const pa::Exception&) {  // bad JSON, a missing field
    return std::nullopt;
  }
}

std::int64_t own_pid() {
#ifdef _WIN32
  return static_cast<std::int64_t>(GetCurrentProcessId());
#else
  return static_cast<std::int64_t>(getpid());
#endif
}

std::int64_t unix_now_ms() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

bool process_alive(std::int64_t pid) {
  if (pid <= 0) {
    return false;
  }
#ifdef _WIN32
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                               static_cast<DWORD>(pid));
  if (process == nullptr) {
    return false;
  }
  DWORD code = 0;
  const bool running =
      GetExitCodeProcess(process, &code) != 0 && code == STILL_ACTIVE;
  CloseHandle(process);
  return running;
#else
  // EPERM: it exists, it is someone else's.
  return kill(static_cast<pid_t>(pid), 0) == 0 || errno == EPERM;
#endif
}

std::vector<RegistryEntry> live_entries(
    const std::string& dir, const std::function<bool(std::int64_t)>& alive) {
  std::vector<RegistryEntry> entries;
  std::vector<fs::Path> files;
  try {
    if (!fs::is_directory(dir)) {
      return entries;
    }
    files = fs::list_directory(dir);
  } catch (const std::exception&) {
    return entries;
  }
  for (const fs::Path& file : files) {
    const std::string name = file.string();
    std::string text;
    if (!name.ends_with(kSuffix) || !pa::file_to_string(name, text)) {
      continue;
    }
    const auto entry = parse_registry_entry(text);
    if (entry && alive(entry->pid)) {
      entries.push_back(*entry);
    }
  }
  std::sort(entries.begin(), entries.end(),
            [](const RegistryEntry& a, const RegistryEntry& b) {
              return a.pid < b.pid;
            });
  return entries;
}

// Written beside its final name and renamed, so a reader never sees half a
// file.
RegistryFile::RegistryFile(const std::string& dir, const RegistryEntry& entry)
    : path_(dir + "/" + std::to_string(entry.pid) + std::string(kSuffix)) {
  const std::string partial = path_ + ".partial";
  try {
    fs::create_directories(dir);
    write_file(partial, registry_entry_json(entry) + "\n");
    fs::rename(partial, path_);
  } catch (const std::exception& error) {
    throw std::runtime_error("cannot write the watch registry entry " + path_ +
                             ": " + error.what());
  }
}

RegistryFile::~RegistryFile() {
  try {
    fs::remove(path_);
  } catch (const std::exception&) {
    // A leftover entry is stale once this process is gone; readers skip it.
  }
}

}  // namespace gamepilot
