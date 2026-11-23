let width = 240.
let height = 160.

let box (b : Wire.box) : Wire.box =
  { x = b.x /. width; y = b.y /. height; w = b.w /. width; h = b.h /. height }
