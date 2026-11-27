type t = { x : int; y : int; w : int; h : int }
type fractions = { left : float; top : float; width : float; height : float }

let frame_width = 1920
let frame_height = 1080

(* Truncated after adding a half, as the fork crops. *)
let pixels size fraction = Float.to_int ((float_of_int size *. fraction) +. 0.5)

let of_fractions f =
  {
    x = pixels frame_width f.left;
    y = pixels frame_height f.top;
    w = pixels frame_width f.width;
    h = pixels frame_height f.height;
  }

let shifted ?(dx = 0) ?(dy = 0) b = { b with x = b.x + dx; y = b.y + dy }

let probe_box ~picture b =
  let across = float_of_int frame_width and down = float_of_int frame_height in
  Switch.Picture_box.whole ~picture
    {
      x = float_of_int b.x /. across;
      y = float_of_int b.y /. down;
      w = float_of_int b.w /. across;
      h = float_of_int b.h /. down;
    }
