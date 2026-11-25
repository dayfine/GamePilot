#include "probe_evaluation.h"

namespace gamepilot {

namespace {

// The uploaded PNG with alpha for `hash`; an empty Mat for no hash.
cv::Mat find_template(const TemplateStore& templates, const std::string& hash) {
  if (hash.empty()) {
    return cv::Mat();
  }
  const cv::Mat* image = templates.find_with_alpha(hash);
  if (image == nullptr) {
    throw RpcError(kInvalidParams, "unknown template: " + hash);
  }
  return *image;
}

// core.find@1 onto a width x height frame: its game pixels are the viewport's
// frame pixels per game pixel on each axis. Its template and shape are not
// scaled: a template is compared at its own size, as the fork's
// ExactImageMatcher scales the blob to it, and a shape is sampled at the blob.
FrameFind map_find_probe(const FindSpec& spec, const TemplateStore& templates,
                         const Viewport& viewport, int width, int height) {
  const double x_scale = viewport.picture.w * width / viewport.game_width;
  const double y_scale = viewport.picture.h * height / viewport.game_height;
  return map_find(spec, x_scale, y_scale,
                  find_template(templates, spec.template_hash),
                  find_template(templates, spec.shape_hash));
}

}  // namespace

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
  if (probe.kind == kFindKind && probe.find) {
    mapped.find =
        map_find_probe(*probe.find, templates, viewport, width, height);
    return mapped;
  }
  if (probe.kind != kTemplateMatchKind) {
    return mapped;
  }
  const cv::Mat* image = templates.find(probe.template_hash);
  if (image == nullptr) {
    throw RpcError(kInvalidParams, "unknown template: " + probe.template_hash);
  }
  // A mask is made in game pixels, where the drawn colors are exact, and
  // scaled after: a seam pixel then blends the masks, not the colors.
  const cv::Mat game_pixels = probe.ink ? ink_mask(*image, *probe.ink) : *image;
  mapped.template_image = scale_template(
      game_pixels,
      template_size_in_frame(viewport, image->size(), width, height));
  if (mapped.template_image.cols > mapped.pixels.width ||
      mapped.template_image.rows > mapped.pixels.height) {
    throw RpcError(kInvalidParams,
                   "box is smaller than the template: " + probe.id);
  }
  return mapped;
}

ProbeResult evaluate_probe(const FrameProbe& probe, const cv::Mat& frame) {
  if (probe.spec.kind == kTemplateMatchKind) {
    TemplateMatch match =
        probe.spec.ink
            ? mask_match(frame, probe.template_image, probe.pixels,
                         *probe.spec.ink)
            : template_match(frame, probe.template_image, probe.pixels);
    match.x = frame_x_to_picture(probe.viewport, match.x / frame.cols);
    match.y = frame_y_to_picture(probe.viewport, match.y / frame.rows);
    return match;
  }
  if (probe.spec.kind == kFindKind) {
    FindResult found = find_blobs(frame, probe.pixels, probe.find);
    found.picture_x = probe.viewport.picture.x * frame.cols;
    found.picture_y = probe.viewport.picture.y * frame.rows;
    return found;
  }
  if (probe.spec.kind == kLineSharesKind) {
    return line_shares(frame, probe.pixels, probe.spec.pixel_test);
  }
  if (probe.spec.kind == kColorCountKind) {
    return color_count(frame, probe.pixels, probe.spec.color_range);
  }
  return color_stats(frame, probe.pixels);
}

}  // namespace gamepilot
