open Grid_maps
open Grid_geometry

type sighting = Spoke | Wild_battle | Nobody

type game_steps = {
  walk_piece : seen:bool -> Connected_maps.place Grid_planning.Leg.t -> unit;
  await_trainer : watch_ms:int -> sighting;
  flee : unit -> unit;
  fight_trainer : unit -> (unit, Pokemon_checkpoints.Failure.cause) result;
  log : string -> unit;
}

type outcome =
  | Walked
  | Stopped_by_trainer of {
      world : Frlg_steps.world;
      at : Connected_maps.place;
      fought : Trainer_sight.trainer list;
    }

type leg = Connected_maps.place Grid_planning.Leg.t
type step = Connected_maps.place Grid_planning.Leg.step

let walk_tiles (leg : leg) =
  match leg.kind with
  | Walk { tiles; to_wall } -> Some (tiles, to_wall)
  | Special_step _ | Face -> None

(* The steps of [tiles] presses of [leg] from its start, up to one that goes
   nowhere. *)
let leg_steps w (leg : leg) tiles =
  let rec go place i acc =
    if i > tiles then List.rev acc
    else
      match Frlg_steps.press w place leg.direction with
      | None -> List.rev acc
      | Some (s : step) -> go s.next (i + 1) (s :: acc)
  in
  go leg.start 1 []

(* The first of [steps] onto a tile a trainer not beaten may see, as its
   count from 1 and its step; the fork's crossing keeps them all. *)
let first_seen w ~beaten steps =
  let seen (s : step) =
    (not s.warped) && Trainer_sight.seeing w ~beaten s.next <> []
  in
  let rec find i = function
    | [] -> None
    | s :: rest -> if seen s then Some (i, s) else find (i + 1) rest
  in
  find 1 steps

let crosses w ~beaten leg =
  match walk_tiles leg with
  | Some (tiles, _) -> first_seen w ~beaten (leg_steps w leg tiles) <> None
  | None -> false

let rec take n = function
  | x :: rest when n > 0 -> x :: take (n - 1) rest
  | _ -> []

(* The first [count] of [steps] of [leg] as a leg of its own: the leg's end,
   warp and facing only when they are all of it. *)
let piece (leg : leg) steps ~count ~tiles ~to_wall : leg =
  let taken = take count steps in
  let last = count >= tiles in
  let finish =
    match List.rev taken with (s : step) :: _ -> s.next | [] -> leg.start
  in
  {
    leg with
    kind = Walk { tiles = count; to_wall = last && to_wall };
    warps = last && leg.warps;
    wild = List.exists (fun (s : step) -> s.wild) taken;
    facing_after = (if last then leg.facing_after else leg.direction);
    finish;
  }

(* After a step onto [at]: the trainers' "!", walk up and text, watched for
   as long as the farthest of them takes; a wild battle is fled and the watch
   begins again. Whether a trainer spoke. *)
let rec trainer_spoke g w ~beaten at =
  let sight = Trainer_sight.sight_onto w ~beaten at in
  let watch_ms = Trainer_sight.full_watch_ms ~approach_tiles:sight in
  let tile = Tile_pos.to_string at.Connected_maps.tile in
  match g.await_trainer ~watch_ms with
  | Nobody ->
      g.log
        (Printf.sprintf "Route: no trainer spoke on %s in %dms." tile watch_ms);
      false
  | Wild_battle ->
      g.log ("Route: a wild battle on " ^ tile ^ ", fled.");
      g.flee ();
      trainer_spoke g w ~beaten at
  | Spoke ->
      g.log ("Route: a trainer saw the player on " ^ tile ^ ": their battle.");
      true

let tiles_text places =
  String.concat " or "
    (List.map
       (fun (p : Connected_maps.place) -> Tile_pos.to_string p.tile)
       places)

(* The world once the trainers who may see [at] have fought the player: each
   beaten, standing on a tile beside the player they may have walked up to. *)
let after_trainer g w at trainers =
  let stands =
    List.concat_map (fun tr -> Trainer_sight.walked_up w tr at) trainers
  in
  g.log
    (Printf.sprintf "Route: the trainer stands on %s; on from %s."
       (tiles_text stands)
       (Tile_pos.to_string at.Connected_maps.tile));
  Stopped_by_trainer
    { world = Frlg_steps.with_walked_up w stands; at; fought = trainers }

let fought g w at trainers =
  Result.map (fun () -> after_trainer g w at trainers) (g.fight_trainer ())

let rec walk_pieces g w ~beaten (leg : leg) ~tiles ~to_wall =
  let steps = leg_steps w leg tiles in
  match first_seen w ~beaten steps with
  | None ->
      g.walk_piece ~seen:false (piece leg steps ~count:tiles ~tiles ~to_wall);
      Ok Walked
  | Some (count, s) ->
      let trainers = Trainer_sight.seeing w ~beaten s.next in
      g.walk_piece ~seen:true (piece leg steps ~count ~tiles ~to_wall);
      if trainer_spoke g w ~beaten s.next then fought g w s.next trainers
      else if count >= tiles then Ok Walked
      else
        let rest = tiles - count in
        walk_pieces g w ~beaten
          { leg with start = s.next; kind = Walk { tiles = rest; to_wall } }
          ~tiles:rest ~to_wall

let walk g w ~beaten leg =
  match walk_tiles leg with
  | Some (tiles, to_wall) -> walk_pieces g w ~beaten leg ~tiles ~to_wall
  | None ->
      g.walk_piece ~seen:false leg;
      Ok Walked

let await_on_screen ~watch_ms =
  let up m =
    Frlg_readers.Dialog.dialog_up m || Frlg_readers.Battle_screen.battle_shows m
  in
  match Effects.await ~timeout_ms:watch_ms up with
  | Timeout -> Nobody
  | Holds m when Frlg_readers.Dialog.dialog_up m -> Spoke
  | Holds _ -> Wild_battle
