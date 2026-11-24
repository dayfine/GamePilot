#include "server.h"

#include "switch_geometry.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <opencv2/imgcodecs.hpp>
#include <vector>

namespace gamepilot {

namespace {

RpcError backend_error(const std::exception& error) {
  pa::JsonObject data;
  data["detail"] = std::string(error.what());
  return RpcError(kBackendError, "backend error", std::move(data));
}

// A frame this far behind its slot is not caught up; pacing restarts from now.
constexpr double kMaxLagMs = 250;
// Longest wait between two network polls while pacing.
constexpr double kMaxPollMs = 50;
// Recorded frames: one a second, 640 wide (Watch-Page.md, Recording).
constexpr double kRecordEveryMs = 1000;
constexpr int kRecordWidth = 640;
// Longest wait for a captured frame before the live loop polls the network
// and the input schedule again.
constexpr double kLivePollMs = 5;

}  // namespace

Server::Server(Backend& backend, ServerOptions options)
    : backend_(backend),
      options_(std::move(options)),
      listener_(listen_local(options_.port)),
      schedule_(backend.info().frame_rate),
      keep_awake_(options_.keepawake, clock_.now_ms()) {
  if (keep_awake_.on() && button_mask(keep_awake_.key()) == 0) {
    throw std::runtime_error("bad keep-awake key " + keep_awake_.key());
  }
  if (!options_.log_path.empty()) {
    if (!wire_log_.open(options_.log_path,
                        pa::FileMode::WRITE | pa::FileMode::BINARY)) {
      throw std::runtime_error("cannot open wire log " + options_.log_path);
    }
  }
  rebase_pacing();
  const double clock_zero_unix_ms =
      static_cast<double>(unix_now_ms()) - clock_.now_ms();
  const bool record = options_.record && !options_.run_folder.empty();
  if (!options_.run_folder.empty()) {
    journal_.emplace(options_.run_folder,
                     DaemonRecord{backend_.info().kind, clock_zero_unix_ms,
                                  record, options_.keepawake.idle_ms / 1000});
  }
  if (options_.watch) {
    start_watch();
  } else if (record) {
    record_stream_ = std::make_unique<FrameStream>(options_.stream);
  }
  if (record) {
    stream()->record_to(RecordOptions{options_.run_folder + "/frames",
                                      kRecordEveryMs, kRecordWidth,
                                      clock_zero_unix_ms});
    std::fprintf(stderr, "daemon: recording frames to %s/frames\n",
                 options_.run_folder.c_str());
  }
  if (keep_awake_.on()) {
    std::fprintf(stderr,
                 "daemon: keep-awake: %s after %.0f s with no input, never "
                 "during a client's batch\n",
                 keep_awake_.key().c_str(), options_.keepawake.idle_ms / 1000);
  }
}

FrameStream* Server::stream() {
  if (watch_) {
    return &watch_->stream();
  }
  return record_stream_.get();
}

bool Server::batch_pending() const {
  return backend_.info().timing == Timing::kLive
             ? live_schedule_.next_event_ms().has_value()
             : !schedule_.empty();
}

// After a long idle, the keep-awake press as a batch of the daemon's own; a
// client's batch, queued or running, or a held lease holds it off
// (keep_awake.h). Each press
// is in the wire log as a `daemon` line.
void Server::keep_awake() {
  if (!keep_awake_.on()) {
    return;
  }
  const double now = clock_.now_ms();
  const bool pending = batch_pending();
  if (pending) {
    keep_awake_.input(now);
    return;
  }
  const double idle = keep_awake_.idle_ms(now);
  if (!keep_awake_.due(now, pending, lease_.holder().has_value())) {
    return;
  }
  const std::string batch(kKeepAwakeBatch);
  if (backend_.info().timing == Timing::kLive) {
    live_schedule_.submit(batch, keep_awake_.press(), now);
  } else {
    schedule_.submit(batch, keep_awake_.press(), backend_.seq());
  }
  keep_awake_.pressed(now);
  log("daemon", keepawake_notification(keep_awake_.key(), idle));
  std::fprintf(stderr, "daemon: keep-awake: pressed %s after %.0f s idle\n",
               keep_awake_.key().c_str(), idle / 1000);
}

// A finished batch's notice, to the client that submitted it: the
// keep-awake's own is not sent.
void Server::send_batch_done(const std::string& batch_id, std::int64_t seq,
                             double t_ms) {
  const auto owner =
      std::find_if(batch_owners_.begin(), batch_owners_.end(),
                   [&](const auto& entry) { return entry.first == batch_id; });
  if (owner == batch_owners_.end()) {
    return;
  }
  const int number = owner->second;
  batch_owners_.erase(owner);
  for (auto& client : clients_) {
    if (client->number == number && client->socket.valid()) {
      send(*client, batch_done_notification(batch_id, seq, t_ms));
    }
  }
}

void Server::rebase_pacing() {
  pace_base_ms_ = clock_.now_ms();
  pace_base_seq_ = backend_.seq();
}

void Server::run(const std::atomic<bool>& stop) {
  if (backend_.info().timing == Timing::kLive) {
    run_live(stop);
  } else {
    run_lockstep(stop);
  }
}

void Server::run_live(const std::atomic<bool>& stop) {
  while (!stop.load()) {
    serve_network(0);
    double now = clock_.now_ms();
    for (const KeySegment& segment : live_schedule_.take_due(now)) {
      backend_.queue_keys(segment.keys, segment.ms);
    }
    const double next =
        live_schedule_.next_event_ms().value_or(now + kMaxPollMs);
    const double wait = std::clamp(next - now, 0.0, kLivePollMs);
    if (const auto frame = backend_.next_frame(wait)) {
      beat_.seq = frame->seq;
      send_probe_results(frame->seq, frame->t_ms);
    }
    now = clock_.now_ms();
    beat_.t_ms = now;
    for (const EndedBatch& done : live_schedule_.take_finished(now)) {
      send_batch_done(done.batch_id, backend_.seq(), now);
    }
    keep_awake();
  }
}

void Server::run_lockstep(const std::atomic<bool>& stop) {
  const double frame_ms = 1000.0 / backend_.info().frame_rate;
  double report_ms = clock_.now_ms();
  std::int64_t report_frames = 0;
  while (!stop.load()) {
    if (!options_.fast) {
      const double due =
          pace_base_ms_ +
          static_cast<double>(backend_.seq() + 1 - pace_base_seq_) * frame_ms;
      const double now = clock_.now_ms();
      if (now < due) {
        serve_network(
            static_cast<int>(std::ceil(std::min(due - now, kMaxPollMs))));
        continue;
      }
      if (now - due > kMaxLagMs) {
        std::fprintf(
            stderr, "daemon: %.0f ms behind the frame clock; pacing from now\n",
            now - due);
        rebase_pacing();
      }
    }
    serve_network(0);
    keep_awake();
    step_frame();

    const double now = clock_.now_ms();
    if (now - report_ms >= 10000) {
      std::fprintf(stderr, "daemon: seq %lld, %.2f frames/s",
                   static_cast<long long>(backend_.seq()),
                   static_cast<double>(frames_stepped_ - report_frames) *
                       1000.0 / (now - report_ms));
      if (watch_) {
        const std::int64_t frames = watch_cost_.frames_encoded;
        std::fprintf(
            stderr,
            "; watch: %s, %d on the stream, %lld frames polled (%lld bytes "
            "each), %.1f ms in all",
            watch_->has_viewers() ? "viewed" : "no viewer",
            watch_->stream().viewers(),
            static_cast<long long>(frames),
            static_cast<long long>(
                frames > 0 ? watch_cost_.frame_bytes / frames : 0),
            watch_cost_.ms);
      }
      std::fputs("\n", stderr);
      report_ms = now;
      report_frames = frames_stepped_;
    }
  }
}

void Server::step_frame() {
  const KeyMask mask = schedule_.mask_at(backend_.seq());
  if (sent_mask_ != mask) {
    backend_.set_keys(mask);
    sent_mask_ = mask;
  }
  const std::int64_t seq = backend_.step();
  frames_stepped_++;
  beat_ = ThreadBeat{"server", seq, clock_.now_ms()};
  send_probe_results(seq, beat_.t_ms);
  for (const FinishedBatch& done : schedule_.take_finished(seq)) {
    send_batch_done(done.batch_id, done.seq, clock_.now_ms());
  }
}

void Server::send_probe_results(std::int64_t seq, double t_ms) {
  const ClientConnection* watched = watched_client();
  if (watched == nullptr) {
    return;
  }
  const cv::Mat frame = backend_.frame();
  for (auto& client : clients_) {
    if (client->probes.empty() || !client->socket.valid()) {
      continue;
    }
    std::vector<std::pair<std::string, ProbeResult>> results;
    for (const FrameProbe& probe : client->probes) {
      results.emplace_back(probe.spec.id, evaluate_probe(probe, frame));
    }
    pa::JsonObject changed = client->sent_results.take_changed(results);
    send(*client, frame_notification(seq, loads_, t_ms, std::move(changed)));
    if (client.get() != watched) {
      continue;
    }
    if (watch_ && (watch_->has_viewers() || watch_->stream().viewers() > 0)) {
      probed_frame_ = frame;
      probed_seq_ = seq;
      show_probes(seq, client->probes, results);
    } else if (stream() != nullptr && stream()->recording()) {
      probed_frame_ = frame;
      probed_seq_ = seq;
    }
  }
}

const ClientConnection* Server::watched_client() const {
  for (const auto& client : clients_) {
    if (!client->probes.empty() && client->socket.valid()) {
      return client.get();
    }
  }
  return nullptr;
}

void Server::serve_network(int timeout_ms) {
  std::vector<const Socket*> sockets{&listener_};
  std::vector<int> numbers;
  for (const auto& client : clients_) {
    sockets.push_back(&client->socket);
    numbers.push_back(client->number);
  }
  const std::size_t page_from = sockets.size();
  if (watch_) {
    const auto page = watch_->sockets();
    sockets.insert(sockets.end(), page.begin(), page.end());
  }
  const auto readable = poll_readable(sockets, timeout_ms);
  // Handling one client's line may drop another (a failed send), so clients
  // are found again by number and removed only after all are served.
  for (std::size_t i = 0; i < numbers.size(); i++) {
    if (!readable[i + 1]) {
      continue;
    }
    for (auto& client : clients_) {
      if (client->number == numbers[i] && client->socket.valid()) {
        read_client(*client);
      }
    }
  }
  std::erase_if(clients_, [](const std::unique_ptr<ClientConnection>& client) {
    return !client->socket.valid();
  });
  if (readable[0]) {
    accept_pending();
  }
  lease_.expire(clock_.now_ms(), batch_pending());
  if (watch_) {
    const double start = clock_.now_ms();
    const auto page_begin =
        readable.begin() + static_cast<std::ptrdiff_t>(page_from);
    watch_->serve(std::vector<bool>(page_begin, readable.end()));
    watch_cost_.ms += clock_.now_ms() - start;
    watch_tick();
  } else if (record_stream_) {
    offer_stream_frame();
  }
}

void Server::accept_pending() {
  Socket socket = accept_client(listener_);
  if (!socket.valid()) {
    return;
  }
  if (clients_.size() >= kMaxClients) {
    const RpcError busy(kInvalidRequest, "busy: the daemon serves " +
                                             std::to_string(kMaxClients) +
                                             " clients at a time");
    socket.send_all(to_line(error_message(pa::JsonValue(), busy)) + "\n");
    return;
  }
  auto client = std::make_unique<ClientConnection>();
  client->number = ++connections_;
  client->socket = std::move(socket);
  std::fprintf(stderr, "daemon: client %d connected\n", client->number);
  clients_.push_back(std::move(client));
}

// Drops queued commands and releases every button.
void Server::clear_input() {
  schedule_.clear();
  live_schedule_.clear();
  batch_owners_.clear();
  backend_.set_keys(0);
  sent_mask_ = KeyMask{0};
}

// The connection's probes and templates go with it; its queued batches too
// when it held the lease (only the holder submits).
void Server::drop_client(ClientConnection& client, const char* reason) {
  const bool held = lease_.release(client.number);
  std::fprintf(stderr, "daemon: client %d disconnected (%s)%s\n", client.number,
               reason, held ? "; lease released, batches dropped" : "");
  if (held) {
    clear_input();
  }
  client.socket.close();
}

void Server::read_client(ClientConnection& client) {
  auto data = client.socket.receive_some();
  if (!data) {
    drop_client(client, "closed");
    return;
  }
  client.lines.append(*data);
  while (client.socket.valid()) {
    auto line = client.lines.next_line();
    if (!line) {
      break;
    }
    if (!line->empty()) {
      handle_line(client, *line);
    }
  }
}

DaemonStatus Server::status() const {
  DaemonStatus status;
  status.t_ms = clock_.now_ms();
  status.backend = backend_.info().kind;
  status.lease = lease_.holder();
  status.clients = static_cast<std::int64_t>(clients_.size());
  if (status.lease && !status.lease->client.empty()) {
    status.client = status.lease->client;
  }
  bool full = false;
  for (const auto& client : clients_) {
    if (!status.client && client->name) {
      status.client = client->name;
    }
    full = full || std::any_of(client->probes.begin(), client->probes.end(),
                               [](const FrameProbe& probe) {
                                 return probe.spec.delivery == "every";
                               });
  }
  status.fidelity = full ? "full" : "latest";
  status.health = backend_.health();
  status.health.threads.push_back(beat_);
  return status;
}

// Input methods need the lease: the client takes it or is refused. Returns
// the owner the wire log names on the line, none for other methods.
std::optional<std::string> Server::take_lease(ClientConnection& client,
                                              const std::string& method) {
  if (method != "submit" && method != "cancel" &&
      method != "backend.load_state") {
    return std::nullopt;
  }
  const double now = clock_.now_ms();
  if (const auto holder =
          lease_.input(client.number, client.name.value_or(""), now)) {
    throw lease_refusal(*holder, now);
  }
  return lease_.holder()->owner;
}

void Server::handle_line(ClientConnection& client, const std::string& line) {
  pa::JsonValue id;
  try {
    pa::JsonValue message;
    try {
      message = parse_message(line);
    } catch (const RpcError&) {
      log("in", pa::JsonValue(line), client.number);
      throw;
    }
    if (take_watch_note(message)) {
      return;  // the page's, not the program's: kept off the wire log
    }
    std::optional<Request> request;
    std::optional<std::string> owner;
    try {
      request.emplace(decode_request(message));
      id = request->id.clone();
      owner = take_lease(client, request->method);
    } catch (const RpcError&) {
      log("in", message, client.number);
      throw;
    }
    log("in", message, client.number, owner);
    pa::JsonObject result = dispatch(client, *request);
    if (request->has_id) {
      send(client, result_message(id, std::move(result)));
    }
  } catch (const RpcError& error) {
    send(client, error_message(id, error));
  }
}

pa::JsonObject Server::dispatch(ClientConnection& client,
                                const Request& request) {
  const std::string& method = request.method;
  if (method == "hello") {
    const HelloParams hello = decode_hello(request.params);
    if (hello.protocol != kProtocolVersion) {
      pa::JsonObject data;
      data["supported"] = kProtocolVersion;
      throw RpcError(kProtocolMismatch, "protocol version mismatch",
                     std::move(data));
    }
    client.name = hello.client;
    return hello_result(backend_.info());
  }
  if (method == "status") {
    return status_result(status());
  }
  if (method == "lease.acquire") {
    const LeaseAcquireParams params = decode_lease_acquire(request.params);
    const double now = clock_.now_ms();
    if (const auto holder =
            lease_.acquire(client.number, params.owner,
                           client.name.value_or(""), params.ttl_ms, now)) {
      throw lease_refusal(*holder, now);
    }
    return lease_acquire_result(*lease_.holder(), now);
  }
  if (method == "lease.release") {
    return lease_release_result(lease_.release(client.number));
  }
  if (method == "backend.save_state") {
    const SaveParams save = decode_save(request.params);
    try {
      return save_result(backend_.save_state(save.path));
    } catch (const BackendError& error) {
      throw backend_error(error);
    }
  }
  if (method == "backend.save_frame") {
    const SaveParams save = decode_save(request.params);
    try {
      save_png(save.path, backend_.frame());
      // The frame a failure saves (failure.png) is recorded too; a shot by a
      // client that does not drive (`gamepilot ctl shot`) is no failure.
      if (!lease_.holder() || lease_.held_by(client.number)) {
        mark_failure();
      }
      return save_result(backend_.seq());
    } catch (const BackendError& error) {
      throw backend_error(error);
    }
  }
  if (method == "probe.upload_template" || method == "subscribe" ||
      method == "unsubscribe") {
    return dispatch_probes(client, request);
  }
  if (method == "submit" || method == "cancel" ||
      method == "backend.load_state") {
    return dispatch_input(client, request);
  }
  throw RpcError(kMethodNotFound, "unknown method: " + method);
}

pa::JsonObject Server::dispatch_probes(ClientConnection& client,
                                       const Request& request) {
  if (request.method == "probe.upload_template") {
    const UploadTemplateParams upload = decode_upload_template(request.params);
    const std::optional<std::string> hash =
        client.templates.add_png(upload.png);
    if (!hash) {
      throw RpcError(kInvalidParams, "png does not decode");
    }
    return upload_template_result(*hash);
  }
  if (request.method == "subscribe") {
    const SubscribeParams subscribe = decode_subscribe(request.params);
    const BackendInfo& info = backend_.info();
    std::vector<FrameProbe> mapped;
    for (const ProbeSpec& probe : subscribe.probes) {
      mapped.push_back(map_probe(probe, client.templates, info.viewport,
                                 info.width, info.height));
    }
    std::vector<std::string> ids;
    for (FrameProbe& probe : mapped) {
      ids.push_back(probe.spec.id);
      std::erase_if(client.probes, [&](const FrameProbe& old) {
        return old.spec.id == probe.spec.id;
      });
      client.probes.push_back(std::move(probe));
    }
    client.sent_results.forget_all();
    return subscribe_result(ids);
  }
  const UnsubscribeParams unsubscribe = decode_unsubscribe(request.params);
  std::vector<std::string> removed;
  for (const std::string& id : unsubscribe.ids) {
    if (std::erase_if(client.probes, [&](const FrameProbe& probe) {
          return probe.spec.id == id;
        }) > 0) {
      client.sent_results.forget(id);
      removed.push_back(id);
    }
  }
  return unsubscribe_result(removed);
}

// Submit, cancel and load_state: take_lease already let the client in.
pa::JsonObject Server::dispatch_input(ClientConnection& client,
                                      const Request& request) {
  const std::string& method = request.method;
  if (method == "backend.load_state") {
    const LoadStateParams load = decode_load_state(request.params);
    try {
      const std::int64_t seq = backend_.load_state(load.path);
      schedule_.clear();
      batch_owners_.clear();
      sent_mask_.reset();
      rebase_pacing();
      for (auto& other : clients_) {
        other->sent_results.forget_all();
      }
      loads_++;
      return load_state_result(seq, loads_);
    } catch (const BackendError& error) {
      throw backend_error(error);
    }
  }
  if (method == "submit") {
    const SubmitParams submit = decode_submit(request.params);
    keep_awake_.input(clock_.now_ms());
    batch_owners_.emplace_back(submit.batch_id, client.number);
    if (backend_.info().timing == Timing::kLive) {
      live_schedule_.submit(submit.batch_id, submit.commands, clock_.now_ms());
      return submit_result(submit.batch_id, backend_.seq());
    }
    const std::int64_t start =
        schedule_.submit(submit.batch_id, submit.commands, backend_.seq());
    return submit_result(submit.batch_id, start);
  }
  decode_cancel(request.params);
  keep_awake_.input(clock_.now_ms());
  clear_input();
  return cancel_result(backend_.seq());
}

void Server::send(ClientConnection& client, const pa::JsonValue& message) {
  if (!client.socket.valid()) {
    return;
  }
  log("out", message, client.number);
  if (!client.socket.send_all(to_line(message) + "\n")) {
    drop_client(client, "send failed");
  }
}

void Server::log(const char* dir, const pa::JsonValue& message,
                 std::optional<int> conn,
                 const std::optional<std::string>& owner) {
  if (!wire_log_.is_open()) {
    return;
  }
  wire_log_.write(to_line(wire_log_line(dir, clock_.now_ms(), message.clone(),
                                        conn, owner)) +
                  "\n");
  wire_log_.flush();
}

}  // namespace gamepilot
