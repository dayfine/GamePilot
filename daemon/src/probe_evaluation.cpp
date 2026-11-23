#include "probe_evaluation.h"

namespace gamepilot {

FrameProbe map_probe(const ProbeSpec& probe, const TemplateStore& templates,
                     const Viewport& viewport, int width, int height) {
  if (!is_known_probe_kind(probe.kind)) {
    pa::JsonObject data;
    data["kind"] = probe.kind;
    throw RpcError(kUnknownProbeKind, "unknown probe kind", std::move(data));
  }
  FrameProbe mapped;
  mapped.spec = probe;
  mapped.viewport = viewport;
  mapped.pixels =
      box_to_pixels(picture_box_to_frame(viewport, probe.box), width, height);
  if (probe.kind != kTemplateMatchKind) {
    return mapped;
  }
  const cv::Mat* image = templates.find(probe.template_hash);
  if (image == nullptr) {
    throw RpcError(kInvalidParams, "unknown template: " + probe.template_hash);
  }
  mapped.template_bgr = scale_template(
      *image, template_size_in_frame(viewport, image->size(), width, height));
  if (mapped.template_bgr.cols > mapped.pixels.width ||
      mapped.template_bgr.rows > mapped.pixels.height) {
    throw RpcError(kInvalidParams,
                   "box is smaller than the template: " + probe.id);
  }
  return mapped;
}

ProbeResult evaluate_probe(const FrameProbe& probe, const cv::Mat& frame) {
  if (probe.spec.kind == kTemplateMatchKind) {
    TemplateMatch match =
        template_match(frame, probe.template_bgr, probe.pixels);
    match.x = frame_x_to_picture(probe.viewport, match.x / frame.cols);
    match.y = frame_y_to_picture(probe.viewport, match.y / frame.rows);
    return match;
  }
  if (probe.spec.kind == kColorCountKind) {
    return color_count(frame, probe.pixels, probe.spec.color_range);
  }
  return color_stats(frame, probe.pixels);
}

}  // namespace gamepilot
