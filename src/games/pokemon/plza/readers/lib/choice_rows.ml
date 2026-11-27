type t = { count : int; selected : int }
type slot = Highlighted | Panel | Other

let max_rows = 6
let min_rows = 2
let width = float_of_int Native_box.frame_width
let height = float_of_int Native_box.frame_height

(* 1080p pixels, which the fork turns into fractions of the frame. *)
type fork_pixels = {
  pitch : float;
  strip_y : float;
  strip_h : float;
  text_end : float;
  scan : float;
  top_band : float;
  bottom_band : float;
  strip_x : float;
  strip_w : float;
  gap : float;
}

let px =
  {
    pitch = 80.;
    strip_y = 748.;
    strip_h = 40.;
    text_end = 1690.;
    scan = 1700.;
    top_band = 736.;
    bottom_band = 796.;
    strip_x = 1698.;
    strip_w = 14.;
    gap = 10.;
  }

let row_pitch = px.pitch /. height
let strip_top = px.strip_y /. height
let strip_height = px.strip_h /. height
let text_end_x = px.text_end /. width
let scan_x = px.scan /. width
let top_band_y = px.top_band /. height
let bottom_band_y = px.bottom_band /. height
let right_strip_x = px.strip_x /. width
let right_strip_w = px.strip_w /. width
let text_gap = px.gap /. width

(* Our own: the farthest left the highlight is followed. *)
let scan_limit = 960
let max_stddev_sum = 30.
let highlight_min = 200.
let panel_max_red = 70.
let panel_max_green = 100.
let panel_min_blue = 80.
let panel_max_blue = 150.
let panel_blue_over_red = 40.
let min_text_share = 0.005
let bright_min = 200
let text_bright_min = 180
let slot_id k = Printf.sprintf "choice_rows.slot%d" k
let band_id band k = Printf.sprintf "choice_rows.%s%d" band k
let text_id k = Printf.sprintf "choice_rows.text%d" k
let pitch k = row_pitch *. float_of_int k

let right_strip k =
  Native_box.of_fractions
    {
      left = right_strip_x;
      top = strip_top -. pitch k;
      width = right_strip_w;
      height = strip_height;
    }

(* Truncated without a half, as the fork picks the pixel to scan from. *)
let pixel size fraction = Float.to_int (fraction *. size)
let scan_from = pixel width scan_x

(* One line of the frame, from the scan's limit to where it starts. *)
let band_line k band_y : Native_box.t =
  {
    x = scan_limit;
    y = pixel height (band_y -. pitch k);
    w = scan_from - scan_limit;
    h = 1;
  }

(* The text bands of every highlight left the scan can find. *)
let text_span k =
  let left = (float_of_int scan_limit /. width) +. text_gap in
  Native_box.of_fractions
    {
      left;
      top = strip_top -. pitch k;
      width = text_end_x -. left;
      height = strip_height;
    }

let channel_max = 255

let gray_from v : Wire.Blob_find.filter =
  { low = (v, v, v); high = (channel_max, channel_max, channel_max) }

let at_least v =
  [
    Wire.Line_shares.at_least ~r:1 ~g:0 ~b:0 v;
    Wire.Line_shares.at_least ~r:0 ~g:1 ~b:0 v;
    Wire.Line_shares.at_least ~r:0 ~g:0 ~b:1 v;
  ]

let row_probes ~picture k =
  let band name y =
    Find_probe.probe ~picture ~id:(band_id name k) (band_line k y)
      (Wire.Blob_find.params ~filters:[ gray_from bright_min ] ~min_area:1. ())
  in
  List.concat
    [
      Box_color.probe ~picture ~id:(slot_id k) (right_strip k);
      band "top" top_band_y;
      band "bottom" bottom_band_y;
      Pixel_shares.probe ~picture ~id:(text_id k) (text_span k)
        (at_least text_bright_min);
    ]

let probes ~picture =
  List.concat_map (row_probes ~picture) (List.init max_rows Fun.id)

let slot_of (s : Box_color.stats) =
  let m = s.mean in
  let panel =
    m.r <= panel_max_red && m.g <= panel_max_green && m.b >= panel_min_blue
    && m.b <= panel_max_blue
    && m.b >= m.r +. panel_blue_over_red
  in
  if Switch.Solid_color.sum s.stddev > max_stddev_sum then Other
  else if m.r >= highlight_min && m.g >= highlight_min && m.b >= highlight_min
  then Highlighted
  else if panel then Panel
  else Other

let slot m k =
  match Box_color.read m (slot_id k) with Some s -> slot_of s | None -> Other

(* The slots from the bottom up, to the first that is neither. *)
let slots m =
  let rec from k =
    if k >= max_rows then []
    else match slot m k with Other -> [] | s -> s :: from (k + 1)
  in
  from 0

(* The pixel the highlight reaches left to: from where the scan starts, left
   while the pixel left of it is white on either line. *)
let highlight_left m k =
  let runs =
    List.concat_map
      (fun band -> Find_probe.read m (band_id band k))
      [ "top"; "bottom" ]
  in
  let covering x (b : Wire.Blob_find.blob) =
    b.x <= float_of_int x && float_of_int x < b.x +. b.w
  in
  let rec left_from x =
    match List.find_opt (covering (x - 1)) runs with
    | Some b when Float.to_int b.x < x -> left_from (Float.to_int b.x)
    | Some _ | None -> x
  in
  left_from scan_from

let has_text m k left =
  let band =
    Native_box.of_fractions
      {
        left = (float_of_int left /. width) +. text_gap;
        top = strip_top -. pitch k;
        width = text_end_x -. ((float_of_int left /. width) +. text_gap);
        height = strip_height;
      }
  in
  let span = text_span k in
  match Pixel_shares.lines m (text_id k) with
  | Some t -> (
      match
        Pixel_shares.window t.columns ~first:(band.x - span.x) ~count:band.w
      with
      | Some share -> share >= min_text_share
      | None -> false)
  | None -> false

(* The rows up to the first plain one without text, and the highlighted ones
   among them. *)
let counted m slots left =
  let rec go k highlighted = function
    | [] -> (k, highlighted)
    | Highlighted :: rest -> go (k + 1) (highlighted + 1) rest
    | (Panel | Other) :: rest ->
        if has_text m k left then go (k + 1) highlighted rest
        else (k, highlighted)
  in
  go 0 0 slots

let first_highlighted slots =
  let rec find k = function
    | [] -> None
    | Highlighted :: _ -> Some k
    | (Panel | Other) :: rest -> find (k + 1) rest
  in
  find 0 slots

let read m =
  let slots = slots m in
  Option.bind (first_highlighted slots) (fun first ->
      let count, highlighted = counted m slots (highlight_left m first) in
      if highlighted <> 1 || count < min_rows then None
      else Some { count; selected = count - 1 - first })
