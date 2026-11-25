open Wire.Line_shares

let slots = 6
let slot_x = 0.045
let slot_pitch = 0.0398
let bar_width = 0.026
let bar_y = 0.9519
let bar_height = 0.0037
let card_y = 0.9454
let card_height = 0.0046

let box ~top ~height i =
  Native_box.of_fractions
    {
      left = slot_x +. (slot_pitch *. float_of_int i);
      top;
      width = bar_width;
      height;
    }

let card_id i = Printf.sprintf "party_slots.card.%d" i

let card_probes ~picture =
  List.concat
    (List.init slots (fun i ->
         Box_color.probe ~picture ~id:(card_id i)
           (box ~top:card_y ~height:card_height i)))

let channels = 3.

let brightness (s : Box_color.stats) =
  (s.mean.r +. s.mean.g +. s.mean.b) /. channels

let all_some xs =
  if List.for_all Option.is_some xs then Some (List.filter_map Fun.id xs)
  else None

let cards m =
  all_some
    (List.init slots (fun i ->
         Option.map brightness (Box_color.read m (card_id i))))

let green =
  [
    { weights = (0, 1, 0); op = Greater; value = 140 };
    { weights = (-1, 1, 0); op = Greater; value = 60 };
    { weights = (0, 1, -1); op = Greater; value = 60 };
  ]

let yellow =
  [
    { weights = (1, 0, 0); op = Greater; value = 170 };
    { weights = (0, 1, 0); op = Greater; value = 150 };
    { weights = (0, 0, 1); op = Less; value = 100 };
  ]

let red =
  [
    { weights = (1, 0, 0); op = Greater; value = 170 };
    { weights = (0, 1, 0); op = Less; value = 110 };
    { weights = (0, 0, 1); op = Less; value = 110 };
  ]

(* The trough: (r + g + b) / 3 under [ratio] times the card, in hundredths:
   100 (r + g + b) under 300 [ratio] times the card, the right side rounded
   up, which keeps the test exact for whole sums. *)
let strict_ratio = 0.65
let relaxed_ratio = 0.72
let hundredths = 100

let dark ratio card =
  let limit = Float.ceil (float_of_int (3 * hundredths) *. ratio *. card) in
  [
    {
      weights = (hundredths, hundredths, hundredths);
      op = Less;
      value = int_of_float limit;
    };
  ]

(* The HP colours, with green and yellow's overlap to take off once. *)
let hp_tests =
  [ ("g", green); ("y", yellow); ("r", red); ("gy", green @ yellow) ]

let tests card =
  hp_tests
  @ List.concat_map
      (fun (k, ratio) ->
        let d = dark ratio card in
        (k, d) :: List.map (fun (n, t) -> (k ^ n, t @ d)) hp_tests)
      [ ("s", strict_ratio); ("x", relaxed_ratio) ]

let bar_id i name = Printf.sprintf "party_slots.bar.%d.%s" i name

let slot_probes ~picture i card =
  let bar = box ~top:bar_y ~height:bar_height i in
  List.concat_map
    (fun (name, test) ->
      Pixel_shares.probe ~picture ~id:(bar_id i name) bar test)
    (tests card)

let bar_probes ~picture cards =
  List.concat (List.mapi (slot_probes ~picture) cards)

type bar = { hp : float; strict : float; relaxed : float }

let share m i name =
  Option.map
    (fun (t : Wire.Line_shares.t) ->
      match t.rows with
      | [] -> 0.
      | rows -> List.fold_left ( +. ) 0. rows /. float_of_int (List.length rows))
    (Pixel_shares.lines m (bar_id i name))

(* Green, yellow and red less green and yellow both, with [prefix]. *)
let hp_share m i prefix =
  match List.map (fun n -> share m i (prefix ^ n)) [ "g"; "y"; "r"; "gy" ] with
  | [ Some g; Some y; Some r; Some gy ] -> Some (g +. y +. r -. gy)
  | _ -> None

let with_trough m i k hp =
  match (share m i k, hp_share m i k) with
  | Some d, Some dark_hp -> Some (hp +. d -. dark_hp)
  | _ -> None

let bar m i =
  match hp_share m i "" with
  | None -> None
  | Some hp -> (
      match (with_trough m i "s" hp, with_trough m i "x" hp) with
      | Some strict, Some relaxed -> Some { hp; strict; relaxed }
      | _ -> None)

let bars m = all_some (List.init slots (bar m))
let hp_share_min = 0.05
let bar_share_min = 0.5

let has_hp_bar b =
  (if b.hp >= hp_share_min then b.relaxed else b.strict) >= bar_share_min

let filled ~sent_out bars =
  List.fold_left
    (fun (i, count) b ->
      (i + 1, if Some i = sent_out || has_hp_bar b then i + 1 else count))
    (0, 0) bars
  |> snd
