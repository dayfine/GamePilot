// Wire protocol v1 (protocol/v1): JSON-RPC 2.0 messages decoded into plain
// structs and encoded back. No I/O here.

#pragma once

#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include "Common/Cpp/Json/JsonArray.h"
#include "Common/Cpp/Json/JsonObject.h"
#include "Common/Cpp/Json/JsonValue.h"
#include "backend.h"
#include "blob_find.h"
#include "input_lease.h"
#include "probes.h"
#include "schedule.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

inline constexpr std::int64_t kProtocolVersion = 1;
inline constexpr const char* kDaemonName = "gamepilot-daemon/0.1";

enum ErrorCode : int {
  kParseError = -32700,
  kInvalidRequest = -32600,
  kMethodNotFound = -32601,
  kInvalidParams = -32602,
  kUnknownProbeKind = -32001,
  kBackendError = -32002,
  kProtocolMismatch = -32003,
  kLeaseHeld = -32004,  // input while another connection holds the lease
};

class RpcError : public std::runtime_error {
 public:
  RpcError(int code, const std::string& message,
           pa::JsonValue data = pa::JsonValue())
      : std::runtime_error(message), code_(code), data_(std::move(data)) {}
  RpcError(const RpcError& other)
      : std::runtime_error(other),
        code_(other.code_),
        data_(other.data_.clone()) {}

  int code() const { return code_; }
  const pa::JsonValue& data() const { return data_; }

 private:
  int code_;
  pa::JsonValue data_;
};

struct Request {
  pa::JsonValue id;  // null for a notification
  bool has_id = false;
  std::string method;
  pa::JsonObject params;
};

struct HelloParams {
  std::int64_t protocol = 0;
  std::string client;
};

struct LoadStateParams {
  std::string path;
};

// backend.save_state and backend.save_frame.
struct SaveParams {
  std::string path;
};

struct UploadTemplateParams {
  std::string png;  // the PNG bytes, decoded from base64
};

struct ProbeSpec {
  std::string id;
  std::string kind;
  Box box;
  std::string delivery;  // "every" or "latest"
  // core.template_match@1 only: the hash probe.upload_template returned, and
  // the optional ink range that makes it compare masks.
  std::string template_hash;
  std::optional<ColorRange> ink;
  // core.color_count@1 only.
  ColorRange color_range;
  // core.line_shares@1 only: what a counted pixel passes.
  PixelTest pixel_test;
  // core.find@1 only.
  std::optional<FindSpec> find;
};

struct SubscribeParams {
  std::vector<ProbeSpec> probes;
};

struct UnsubscribeParams {
  std::vector<std::string> ids;
};

struct SubmitParams {
  std::string batch_id;
  std::vector<InputCommand> commands;
};

struct CancelParams {};

struct LeaseAcquireParams {
  std::string owner;
  double ttl_ms = kDefaultLeaseTtlMs;
};

// The daemon's health, for `status`.
struct DaemonStatus {
  double t_ms = 0;
  std::string backend;  // BackendInfo::kind
  // The lease holder's hello name, else the oldest connection's that said
  // hello.
  std::optional<std::string> client;
  std::int64_t clients = 0;  // connections now
  std::optional<LeaseHolder> lease;
  std::string fidelity;  // "full" while an `every` probe is
                         // subscribed, else "latest"
  BackendHealth health;  // threads: the backend's, then the server's
};

// Parses one line. Throws RpcError kParseError.
pa::JsonValue parse_message(const std::string& line);

// Checks the JSON-RPC envelope. Throws RpcError kInvalidRequest.
Request decode_request(const pa::JsonValue& message);

// Each throws RpcError kInvalidParams naming the bad field.
HelloParams decode_hello(const pa::JsonObject& params);
LoadStateParams decode_load_state(const pa::JsonObject& params);
SaveParams decode_save(const pa::JsonObject& params);
UploadTemplateParams decode_upload_template(const pa::JsonObject& params);
SubscribeParams decode_subscribe(const pa::JsonObject& params);
UnsubscribeParams decode_unsubscribe(const pa::JsonObject& params);
SubmitParams decode_submit(const pa::JsonObject& params);
CancelParams decode_cancel(const pa::JsonObject& params);
LeaseAcquireParams decode_lease_acquire(const pa::JsonObject& params);

// Button name ("A", "Start", ..., "Home") to its KeyMask bit; 0 if unknown.
KeyMask button_mask(const std::string& name);

// The refusal of a press of a Switch-only button (kSwitchOnlyKeys, named by
// the first one in `mask`) by a backend that is not the Switch
// (kInvalidParams, data {backend, button}).
RpcError switch_button_refusal(const std::string& backend, KeyMask mask);

pa::JsonValue result_message(const pa::JsonValue& id, pa::JsonObject result);
pa::JsonValue error_message(const pa::JsonValue& id, const RpcError& error);

pa::JsonObject hello_result(const BackendInfo& backend);
pa::JsonObject load_state_result(std::int64_t seq, std::int64_t load);
pa::JsonObject save_result(std::int64_t seq);
pa::JsonObject upload_template_result(const std::string& hash);
pa::JsonObject subscribe_result(const std::vector<std::string>& ids);
pa::JsonObject unsubscribe_result(const std::vector<std::string>& ids);
pa::JsonObject submit_result(const std::string& batch_id,
                             std::int64_t start_seq);
pa::JsonObject cancel_result(std::int64_t released_seq);
pa::JsonObject status_result(const DaemonStatus& status);
// The lease as `lease.acquire`, `status` and a refusal show it: {owner,
// client, held_ms, ttl_ms}.
pa::JsonObject lease_json(const LeaseHolder& holder, double now_ms);
pa::JsonObject lease_acquire_result(const LeaseHolder& holder, double now_ms);
pa::JsonObject lease_release_result(bool released);
// The refusal of input while `holder` holds the lease (kLeaseHeld).
RpcError lease_refusal(const LeaseHolder& holder, double now_ms);
// The refusal of `method` (input or lease.acquire) by a view-only backend
// (kBackendError, data {backend, method}).
RpcError view_only_refusal(const std::string& backend,
                           const std::string& method);

// One probe result as sent: its `kind` and fields, rounded.
pa::JsonObject probe_result_json(const ProbeResult& result);

// A `probes` object of every result: {id: result}.
pa::JsonObject probe_results_json(
    const std::vector<std::pair<std::string, ProbeResult>>& results);

// `load`: how many backend.load_state calls succeeded before this frame.
// `probes`: {id: result} for the results this frame carries (SentResults).
pa::JsonValue frame_notification(std::int64_t seq, std::int64_t load,
                                 double t_ms, pa::JsonObject probes);
pa::JsonValue batch_done_notification(const std::string& batch_id,
                                      std::int64_t seq, double t_ms);
// Tells the program someone pressed Stop on the watch page (contract v1.6).
pa::JsonValue stop_notification(const std::string& reason);
// The daemon's keep-awake press (keep_awake.h), for the wire log's `daemon`
// line: the key and how long the console was idle.
pa::JsonValue keepawake_notification(const std::string& key, double idle_ms);

// One wire log line: {"dir": "in"|"out"|"daemon", "t_ms", "msg"}, with the
// connection's number (`conn`) on its messages and the lease owner (`owner`)
// on an input it sent.
pa::JsonValue wire_log_line(
    const char* dir, double t_ms, pa::JsonValue msg,
    std::optional<int> conn = std::nullopt,
    const std::optional<std::string>& owner = std::nullopt);

// Compact one-line JSON.
std::string to_line(const pa::JsonValue& value);

}  // namespace gamepilot
