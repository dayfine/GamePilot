type t = Wire.box

let whole_frame : t = { x = 0.; y = 0.; w = 1.; h = 1. }

let switch_capture : t =
  { x = 0.09375; y = 0.00462963; w = 0.8125; h = 0.962963 }

let box (screen : t) (b : Wire.box) : Wire.box =
  {
    x = screen.x +. (b.x *. screen.w);
    y = screen.y +. (b.y *. screen.h);
    w = b.w *. screen.w;
    h = b.h *. screen.h;
  }

let color_stats_probe screen ~id b =
  Wire.color_stats_probe ~id ~box:(box screen b) ~delivery:Every
