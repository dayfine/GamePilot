(* One move from the game's box into HOME's (Box_moves), on a scripted box
   screen (Scripted_boxes) whose screens are console B's captures of the BDSP
   banking run: box 152, its first empty slot left to right row 4, column 4
   (the capture after banking has it filled and the game's first row empty).
   The console counts the presses: six Rights put the cursor on the game's
   first slot, Y there picks it up, Y after the move's Downs and Lefts drops
   it, Ups and Lefts back put the cursor on HOME's first slot. *)

open Pokemon_home
module S = Scripted_boxes

let move ?(boxes = [ 152 ]) ?(game_col = 0) () : Box_moves.t =
  { name = "Turtwig"; game_col; boxes; order = Left_to_right }

(* The console: three Lefts after the drop bring the cursor home. *)
let console ~drops () =
  let rights = ref 0 and held = ref false and lefts = ref 0 in
  fun (t : S.t) (b : Wire.button) ->
    match (b, t.screen) with
    | Wire.Right, S.Before ->
        incr rights;
        if !rights = 6 then t.screen <- S.Before_on_game 0
    | Wire.Y, S.Before_on_game _ when not !held -> held := true
    | Wire.Y, S.Before_on_game _ when drops -> t.screen <- S.After
    | Wire.Left, S.After ->
        incr lefts;
        if !lefts = 3 then t.screen <- S.After_home_first
    | _ -> ()

let run ?(drops = true) start m () =
  S.play ~start (console ~drops ()) (fun () ->
      match Box_moves.run ~log:ignore m with
      | Ok () -> "ok"
      | Error e -> "error: " ^ e)

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "box_moves"
    [
      case "into box 152's first empty slot, left to right"
        (run S.Before (move ()))
        "ok; Right x6, Y, Down x3, Left x3, Y, Up x3, Left x3; ends on after, \
         cursor on HOME's first slot";
      case "the drop does not land: an error, nothing more pressed"
        (run ~drops:false S.Before (move ()))
        "error: Turtwig did not land in HOME box 152, row 4 column 4; Pokémon \
         HOME left open, unsaved; Right x6, Y, Down x3, Left x3, Y; ends on \
         before, cursor on game slot 0";
      case "no Pokémon in the game's slot: nothing pressed"
        (run S.After_home_first (move ()))
        "error: no Pokémon in the game's box row 1 column 1 for Turtwig; no \
         press; ends on after, cursor on HOME's first slot";
      case "the cursor not on HOME's first slot: nothing pressed"
        (run S.After (move ()))
        "error: the cursor is not on HOME's box row 1 column 1; no press; ends \
         on after";
    ]
