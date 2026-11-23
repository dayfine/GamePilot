#include "server.h"

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

// Writes `frame` to `path` as a PNG. Throws BackendError.
void write_png(const cv::Mat& frame, const std::string& path) {
  std::vector<unsigned char> png;
  if (!cv::imencode(".png", frame, png)) {
    throw BackendError("cannot encode the frame as PNG");
  }
  pa::FileIO file;
  if (!file.open(path, pa::FileMode::WRITE | pa::FileMode::BINARY) ||
      file.write(png.data(), png.size()) != png.size()) {
    throw BackendError("cannot write " + path);
  }
}

// A frame this far behind its slot is not caught up; pacing restarts from now.
constexpr double kMaxLagMs = 250;
// Longest wait between two network polls while pacing.
constexpr double kMaxPollMs = 50;
// Longest wait for a captured frame before the live loop polls the network
// and the input schedule again.
constexpr double kLivePollMs = 5;

}  // namespace

Server::Server(Backend& backend, ServerOptions options)
    : backend_(backend),
      options_(std::move(options)),
      listener_(listen_local(options_.port)),
      schedule_(backend.info().frame_rate) {
  if (!options_.log_path.empty()) {
    if (!wire_log_.open(options_.log_path,
                        pa::FileMode::WRITE | pa::FileMode::BINARY)) {
      throw std::runtime_error("cannot open wire log " + options_.log_path);
    }
  }
  rebase_pacing();
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
      send(batch_done_notification(done.batch_id, backend_.seq(), now));
    }
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
    step_frame();

    const double now = clock_.now_ms();
    if (now - report_ms >= 10000) {
      std::fprintf(stderr, "daemon: seq %lld, %.2f frames/s\n",
                   static_cast<long long>(backend_.seq()),
                   static_cast<double>(frames_stepped_ - report_frames) *
                       1000.0 / (now - report_ms));
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
    if (client_.valid()) {
      send(batch_done_notification(done.batch_id, done.seq, clock_.now_ms()));
    }
  }
}

void Server::send_probe_results(std::int64_t seq, double t_ms) {
  if (!client_.valid() || probes_.empty()) {
    return;
  }
  const cv::Mat frame = backend_.frame();
  std::vector<std::pair<std::string, ProbeResult>> results;
  for (const FrameProbe& probe : probes_) {
    results.emplace_back(probe.spec.id, evaluate_probe(probe, frame));
  }
  send(frame_notification(seq, loads_, t_ms,
                          sent_results_.take_changed(results)));
}

void Server::serve_network(int timeout_ms) {
  const auto readable =
      poll_readable({&listener_, &client_, &observer_}, timeout_ms);
  if (readable[0]) {
    accept_pending();
  }
  if (readable[1]) {
    read_client();
  }
  if (readable[2]) {
    read_observer();
  }
}

void Server::accept_pending() {
  Socket socket = accept_client(listener_);
  if (!socket.valid()) {
    return;
  }
  if (client_.valid()) {
    if (!observer_.valid()) {
      observer_ = std::move(socket);
      observer_lines_ = LineBuffer();
      return;
    }
    const RpcError busy(kInvalidRequest,
                        "busy: the daemon serves one client at a time");
    socket.send_all(to_line(error_message(pa::JsonValue(), busy)) + "\n");
    return;
  }
  client_ = std::move(socket);
  client_lines_ = LineBuffer();
  std::fprintf(stderr, "daemon: client connected\n");
}

void Server::drop_client(const char* reason) {
  std::fprintf(stderr,
               "daemon: client disconnected (%s); probes and batches dropped\n",
               reason);
  client_.close();
  client_name_.reset();
  probes_.clear();
  live_schedule_.clear();
  sent_results_.forget_all();
  templates_.clear();
  schedule_.clear();
}

void Server::read_client() {
  auto data = client_.receive_some();
  if (!data) {
    drop_client("closed");
    return;
  }
  client_lines_.append(*data);
  while (client_.valid()) {
    auto line = client_lines_.next_line();
    if (!line) {
      break;
    }
    if (!line->empty()) {
      handle_line(*line);
    }
  }
}

void Server::read_observer() {
  auto data = observer_.receive_some();
  if (!data) {
    observer_.close();
    return;
  }
  observer_lines_.append(*data);
  while (observer_.valid()) {
    auto line = observer_lines_.next_line();
    if (!line) {
      break;
    }
    if (!line->empty()) {
      handle_observer_line(*line);
    }
  }
}

// An observer may only ask for `status`; anything else is answered busy.
void Server::handle_observer_line(const std::string& line) {
  pa::JsonValue id;
  pa::JsonValue reply;
  try {
    const Request request = decode_request(parse_message(line));
    id = request.id.clone();
    if (request.method != "status") {
      throw RpcError(
          kInvalidRequest,
          "busy: another client is connected; only status is served");
    }
    reply = result_message(id, status_result(status()));
  } catch (const RpcError& error) {
    reply = error_message(id, error);
  }
  if (!observer_.send_all(to_line(reply) + "\n")) {
    observer_.close();
  }
}

DaemonStatus Server::status() const {
  DaemonStatus status;
  status.t_ms = clock_.now_ms();
  status.backend = backend_.info().kind;
  status.client = client_name_;
  const bool full = std::any_of(
      probes_.begin(), probes_.end(),
      [](const FrameProbe& probe) { return probe.spec.delivery == "every"; });
  status.fidelity = full ? "full" : "latest";
  status.health = backend_.health();
  status.health.threads.push_back(beat_);
  return status;
}

void Server::handle_line(const std::string& line) {
  pa::JsonValue id;
  try {
    pa::JsonValue message;
    try {
      message = parse_message(line);
    } catch (const RpcError&) {
      log("in", pa::JsonValue(line));
      throw;
    }
    log("in", message);
    Request request = decode_request(message);
    id = request.id.clone();
    pa::JsonObject result = dispatch(request);
    if (request.has_id) {
      send(result_message(id, std::move(result)));
    }
  } catch (const RpcError& error) {
    send(error_message(id, error));
  }
}

pa::JsonObject Server::dispatch(const Request& request) {
  const std::string& method = request.method;
  if (method == "hello") {
    const HelloParams hello = decode_hello(request.params);
    if (hello.protocol != kProtocolVersion) {
      pa::JsonObject data;
      data["supported"] = kProtocolVersion;
      throw RpcError(kProtocolMismatch, "protocol version mismatch",
                     std::move(data));
    }
    client_name_ = hello.client;
    return hello_result(backend_.info());
  }
  if (method == "status") {
    return status_result(status());
  }
  if (method == "backend.load_state") {
    const LoadStateParams load = decode_load_state(request.params);
    try {
      const std::int64_t seq = backend_.load_state(load.path);
      schedule_.clear();
      sent_mask_.reset();
      rebase_pacing();
      sent_results_.forget_all();
      loads_++;
      return load_state_result(seq, loads_);
    } catch (const BackendError& error) {
      throw backend_error(error);
    }
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
      write_png(backend_.frame(), save.path);
      return save_result(backend_.seq());
    } catch (const BackendError& error) {
      throw backend_error(error);
    }
  }
  if (method == "probe.upload_template") {
    const UploadTemplateParams upload = decode_upload_template(request.params);
    const std::optional<std::string> hash = templates_.add_png(upload.png);
    if (!hash) {
      throw RpcError(kInvalidParams, "png does not decode");
    }
    return upload_template_result(*hash);
  }
  if (method == "subscribe") {
    const SubscribeParams subscribe = decode_subscribe(request.params);
    const BackendInfo& info = backend_.info();
    std::vector<FrameProbe> mapped;
    for (const ProbeSpec& probe : subscribe.probes) {
      mapped.push_back(
          map_probe(probe, templates_, info.viewport, info.width, info.height));
    }
    std::vector<std::string> ids;
    for (FrameProbe& probe : mapped) {
      ids.push_back(probe.spec.id);
      std::erase_if(probes_, [&](const FrameProbe& old) {
        return old.spec.id == probe.spec.id;
      });
      probes_.push_back(std::move(probe));
    }
    sent_results_.forget_all();
    return subscribe_result(ids);
  }
  if (method == "unsubscribe") {
    const UnsubscribeParams unsubscribe = decode_unsubscribe(request.params);
    std::vector<std::string> removed;
    for (const std::string& id : unsubscribe.ids) {
      if (std::erase_if(probes_, [&](const FrameProbe& probe) {
            return probe.spec.id == id;
          }) > 0) {
        sent_results_.forget(id);
        removed.push_back(id);
      }
    }
    return unsubscribe_result(removed);
  }
  if (method == "submit") {
    const SubmitParams submit = decode_submit(request.params);
    if (backend_.info().timing == Timing::kLive) {
      live_schedule_.submit(submit.batch_id, submit.commands, clock_.now_ms());
      return submit_result(submit.batch_id, backend_.seq());
    }
    const std::int64_t start =
        schedule_.submit(submit.batch_id, submit.commands, backend_.seq());
    return submit_result(submit.batch_id, start);
  }
  if (method == "cancel") {
    decode_cancel(request.params);
    schedule_.clear();
    live_schedule_.clear();
    backend_.set_keys(0);
    sent_mask_ = KeyMask{0};
    return cancel_result(backend_.seq());
  }
  throw RpcError(kMethodNotFound, "unknown method: " + method);
}

void Server::send(const pa::JsonValue& message) {
  if (!client_.valid()) {
    return;
  }
  log("out", message);
  if (!client_.send_all(to_line(message) + "\n")) {
    drop_client("send failed");
  }
}

void Server::log(const char* dir, const pa::JsonValue& message) {
  if (!wire_log_.is_open()) {
    return;
  }
  wire_log_.write(
      to_line(wire_log_line(dir, clock_.now_ms(), message.clone())) + "\n");
  wire_log_.flush();
}

}  // namespace gamepilot
