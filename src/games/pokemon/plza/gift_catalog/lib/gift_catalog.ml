type date = { year : int; month : int; day : int }
type how = Code | Internet | Home
type box_slot = { box : int; slot : int }
type home_order = Left_to_right | Right_to_left

type pokemon = {
  box_slot : box_slot;
  home_boxes : int list;
  home_order : home_order;
}

type gift = {
  id : string;
  name : string;
  how : how;
  code : string option;
  expires : date;
  pokemon : pokemon option;
  source : string;
}

type t = gift list

(* The Gregorian calendar's leap years and month lengths. *)
let leap_every = 4
let century = 100
let leap_century = 400
let long_month = 31
let short_month = 30
let february = 2
let november = 11
let short_months = [ 4; 6; 9; november ]
let months = 12

let leap year =
  (year mod leap_every = 0 && year mod century <> 0)
  || year mod leap_century = 0

let days_in ~year month =
  if month = february then
    if leap year then short_month - 1 else short_month - 2
  else if List.mem month short_months then short_month
  else long_month

(* "YYYY-MM-DD": ten characters. *)
let iso_length = 10

let parts s =
  if String.length s <> iso_length then None
  else
    Scanf.sscanf_opt s "%4u-%2u-%2u%!" (fun year month day ->
        { year; month; day })

let real d =
  d.month >= 1 && d.month <= months && d.day >= 1
  && d.day <= days_in ~year:d.year d.month

let date_of_string s =
  match parts s with
  | Some d when real d -> Ok d
  | _ -> Error (Printf.sprintf "%S is not a day written YYYY-MM-DD" s)

let date_to_string d = Printf.sprintf "%04d-%02d-%02d" d.year d.month d.day
let compare_date a b = compare (a.year, a.month, a.day) (b.year, b.month, b.day)

let how_name = function
  | Code -> "code"
  | Internet -> "internet"
  | Home -> "home"

let expired ~today g = compare_date g.expires today < 0

let line g =
  Printf.sprintf "%s: %s, by %s, until %s" g.id g.name (how_name g.how)
    (date_to_string g.expires)

let lines = List.map line

let slot_cell = function
  | None -> "none (items)"
  | Some p -> Printf.sprintf "Box %d slot %d" p.box_slot.box p.box_slot.slot

let home_cell = function
  | None -> ""
  | Some p -> String.concat ", " (List.map string_of_int p.home_boxes)

let row g =
  Printf.sprintf "| %s | %s | %s | %s | %s | %s |" g.name (how_name g.how)
    (Option.fold ~none:"" ~some:(Printf.sprintf "`%s`") g.code)
    (date_to_string g.expires) (slot_cell g.pokemon) (home_cell g.pokemon)

let guide_table catalog =
  String.concat "\n"
    ([
       "| Gift | How | Code | Last day | Lands in | HOME boxes |";
       "|---|---|---|---|---|---|";
     ]
    @ List.map row catalog)
