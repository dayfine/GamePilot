open Json_fields

type json = Yojson.Safe.t
type filter = { low : int * int * int; high : int * int * int }

type params = {
  filters : filter list;
  min_area : float;
  max_area : float option;
  min_size : (float * float) option;
  max_size : (float * float) option;
  margin : float option;
  shape : string option;
}

type blob = {
  filter : int;
  x : float;
  y : float;
  w : float;
  h : float;
  fill : float;
  stray : float option;
  score : float option;
  overlap : float option;
}

let channel_max = 255
let in_channels c = c >= 0 && c <= channel_max

let filter_ok { low = lr, lg, lb; high = hr, hg, hb } =
  List.for_all in_channels [ lr; lg; lb; hr; hg; hb ]
  && lr <= hr && lg <= hg && lb <= hb

let pair_ok = function Some (w, h) -> w >= 0. && h >= 0. | None -> true

let check p =
  let area_ok =
    p.min_area >= 1.
    && Option.fold ~none:true ~some:(fun m -> m >= p.min_area) p.max_area
  in
  if p.filters = [] then Error "core.find@1 needs a filter"
  else if not (List.for_all filter_ok p.filters) then
    Error "core.find@1: a filter's low end is above its high end or off 0..255"
  else if not area_ok then
    Error "core.find@1: min_area must be at least 1 and at most max_area"
  else if not (pair_ok p.min_size && pair_ok p.max_size) then
    Error "core.find@1: sizes must be >= 0"
  else if Option.fold ~none:false ~some:(fun m -> m < 0.) p.margin then
    Error "core.find@1: margin must be >= 0"
  else Ok p

let params ?max_area ?min_size ?max_size ?margin ?shape ~filters ~min_area () =
  check { filters; min_area; max_area; min_size; max_size; margin; shape }

let channels_of_json what j =
  match List.map (to_int what) (to_list what j) with
  | [ r; g; b ] -> (r, g, b)
  | _ -> fail "%s: expected [r, g, b]" what

let json_of_channels (r, g, b) = `List [ `Int r; `Int g; `Int b ]

let filter_of_json what j =
  {
    low = channels_of_json (what ^ ".min") (field what "min" j);
    high = channels_of_json (what ^ ".max") (field what "max" j);
  }

let pair_of_json what j =
  match List.map (to_float what) (to_list what j) with
  | [ w; h ] -> (w, h)
  | _ -> fail "%s: expected [w, h]" what

let opt what name decode j =
  Option.map (decode (what ^ "." ^ name)) (field_opt what name j)

let params_of_json what j =
  {
    filters =
      List.map
        (filter_of_json (what ^ ".filters"))
        (list_field what "filters" j);
    min_area = float_field what "min_area" j;
    max_area = opt what "max_area" to_float j;
    min_size = opt what "min_size" pair_of_json j;
    max_size = opt what "max_size" pair_of_json j;
    margin = opt what "margin" to_float j;
    shape = opt what "shape" to_string j;
  }

let json_of_filter { low; high } =
  `Assoc [ ("min", json_of_channels low); ("max", json_of_channels high) ]

let json_of_pair (w, h) = `List [ `Float w; `Float h ]
let some name encode = function Some v -> [ (name, encode v) ] | None -> []
let float_json v = `Float v

let params_fields p =
  [
    ("filters", `List (List.map json_of_filter p.filters));
    ("min_area", `Float p.min_area);
  ]
  @ some "max_area" float_json p.max_area
  @ some "min_size" json_of_pair p.min_size
  @ some "max_size" json_of_pair p.max_size
  @ some "margin" float_json p.margin
  @ some "shape" (fun s -> `String s) p.shape

let ( let* ) = Option.bind

let blob_of_json j =
  let num name = Option.bind (member_opt name j) number_opt in
  let* filter = num "filter" in
  let* x = num "x" in
  let* y = num "y" in
  let* w = num "w" in
  let* h = num "h" in
  let* fill = num "fill" in
  Some
    {
      filter = int_of_float filter;
      x;
      y;
      w;
      h;
      fill;
      stray = num "stray";
      score = num "score";
      overlap = num "overlap";
    }

let of_json j =
  match member_opt "blobs" j with
  | Some (`List items) -> all_opt blob_of_json items
  | _ -> None

let json_of_blob b =
  `Assoc
    ([
       ("filter", `Int b.filter);
       ("x", `Float b.x);
       ("y", `Float b.y);
       ("w", `Float b.w);
       ("h", `Float b.h);
       ("fill", `Float b.fill);
     ]
    @ some "stray" float_json b.stray
    @ some "score" float_json b.score
    @ some "overlap" float_json b.overlap)

let kind = "core.find@1"

let to_json blobs =
  `Assoc
    [ ("kind", `String kind); ("blobs", `List (List.map json_of_blob blobs)) ]
