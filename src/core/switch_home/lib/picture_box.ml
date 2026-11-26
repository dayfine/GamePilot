let relative ~(picture : Wire.box) ~x0 ~y0 ~x1 ~y1 : Wire.box =
  {
    x = (x0 -. picture.x) /. picture.w;
    y = (y0 -. picture.y) /. picture.h;
    w = (x1 -. x0) /. picture.w;
    h = (y1 -. y0) /. picture.h;
  }

let clipped ~(picture : Wire.box) ({ x; y; w; h } : Wire.box) =
  let x0 = Float.max x picture.x and y0 = Float.max y picture.y in
  let x1 = Float.min (x +. w) (picture.x +. picture.w)
  and y1 = Float.min (y +. h) (picture.y +. picture.h) in
  if x1 <= x0 || y1 <= y0 then None
  else Some (relative ~picture ~x0 ~y0 ~x1 ~y1)

let whole ~(picture : Wire.box) ({ x; y; w; h } as box : Wire.box) =
  let inside =
    x >= picture.x && y >= picture.y
    && x +. w <= picture.x +. picture.w
    && y +. h <= picture.y +. picture.h
  in
  if inside then clipped ~picture box else None

let native (p : Wire.box) = p.x = 0. && p.y = 0. && p.w = 1. && p.h = 1.
