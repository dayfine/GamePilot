#include "probe_evaluation.h"

namespace gamepilot {

void check_probe(const ProbeSpec& probe, const TemplateStore& templates,
                 int width, int height) {
  if (!is_known_probe_kind(probe.kind)) {
    pa::JsonObject data;
    data["kind"] = probe.kind;
    throw RpcError(kUnknownProbeKind, "unknown probe kind", std::move(data));
  }
  if (probe.kind != kTemplateMatchKind) {
    return;
  }
  const cv::Mat* image = templates.find(probe.template_hash);
  if (image == nullptr) {
    throw RpcError(kInvalidParams, "unknown template: " + probe.template_hash);
  }
  if (!template_fits_box(*image, probe.box, width, height)) {
    throw RpcError(kInvalidParams,
                   "box is smaller than the template: " + probe.id);
  }
}

ProbeResult evaluate_probe(const ProbeSpec& probe, const cv::Mat& frame,
                           const TemplateStore& templates) {
  if (probe.kind == kTemplateMatchKind) {
    return template_match(frame, *templates.find(probe.template_hash),
                          probe.box);
  }
  return color_stats(frame, probe.box);
}

}  // namespace gamepilot
