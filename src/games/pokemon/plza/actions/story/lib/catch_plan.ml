type target = { x : float; y : float; caught : bool option }

let caught_text t =
  match t.caught with
  | None -> "caught mark unread"
  | Some true -> "caught"
  | Some false -> "not caught"

let near_plate_y = 0.45
let steps_before_first_throw = 4
let steps_after_miss = 2

let step_toward t ~misses ~steps =
  t.y < near_plate_y
  && steps < if misses = 0 then steps_before_first_throw else steps_after_miss

let same_within = 0.03

let same a b =
  Float.abs (a.x -. b.x) <= same_within && Float.abs (a.y -. b.y) <= same_within

let nearest_uncaught targets =
  List.fold_left
    (fun (i, best) t ->
      let best =
        match best with
        | _ when t.caught = Some true -> best
        | Some (_, b) when t.y <= b.y -> best
        | _ -> Some (i, t)
      in
      (i + 1, best))
    (0, None) targets
  |> snd |> Option.map fst

type cycle = {
  max_views : int;
  seen : target list;  (** newest first *)
  current : int;
  is_done : bool;
}

let cycle ~max_views = { max_views; seen = []; current = 0; is_done = false }
let targets c = List.rev c.seen
let first c = match List.rev c.seen with t :: _ -> Some t | [] -> None
let over c = ({ c with is_done = true }, false)

let add c t =
  match c.seen with
  | _ when c.is_done -> (c, false)
  | last :: _ when same t last -> over c
  | _ :: _ :: _ when Option.fold ~none:false ~some:(same t) (first c) ->
      over { c with current = 0 }
  | seen ->
      let seen = t :: seen in
      let is_done = List.length seen >= c.max_views in
      ({ c with seen; current = List.length seen - 1; is_done }, not is_done)

let flicks_to c i = i - c.current
let first_read_looks = 8
let held_looks = 13
let max_looks = 32

let settled_party_slots read =
  let rec look n count held =
    if n >= max_looks then count
    else
      match read () with
      | None when count = None && n + 1 >= first_read_looks -> None
      | None -> look (n + 1) count held
      | Some now ->
          let held = if Some now = count then held + 1 else 1 in
          if held >= held_looks then Some now else look (n + 1) (Some now) held
  in
  look 0 None 0
