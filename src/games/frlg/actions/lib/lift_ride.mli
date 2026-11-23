(** Riding a lift, the Rocket Hideout's or the Celadon Department Store's (one
    room layout): its panel's menu, the presses that pick a floor, and the ride
    from below a floor's lift door to a tile south of another floor's. The
    story's ["lift_floor"] game action. Ported from the fork's
    Programs/AutoStory/PokemonFRLG_AutoStoryHideoutLift and
    PokemonFRLG_AutoStoryHideout ([lift_menu()], [lift_exits()],
    [parse_lift_floor_step()], [lift_menu_presses()], [pick_lift_floor()],
    [ride_lift()]), its room legs (PokemonFRLG_AutoStoryRooms: [lift_in_legs()],
    [lift_out_legs()], [walk_room_legs()]) and exits
    (Overworld/PokemonFRLG_CodedRooms).

    Where it differs: the fork confirms a warp by comparing whole frames
    ([warp_left_scene()]); here a black fade is the fade reader's, and the
    lift's way out, whose fade only dims, is the middle of the screen changing
    from before the step and then holding still ({!dim_warp_change}). *)

type lift = Rocket_hideout | Dept_store

type ride = {
  lift : lift;
  from : int;  (** The menu row the cursor starts on: the floor stood at. *)
  to_ : int;  (** The row of the floor ridden to. *)
}

val menu : lift -> string list
(** The panel's menu, top first: B1F, B2F, B4F, EXIT (pokefirered
    sMultichoiceList_RocketHideoutElevator); 5F, 4F, 3F, 2F, 1F, EXIT
    (sMultichoiceList_DeptStoreElevator). *)

val exits : lift -> Story.Pose.grid list
(** Where the lift lets the player out for each floor of its menu, top first: a
    tile south of the floor's lift door, facing south (the game walks the player
    off it). *)

val ride_of_floors : from:string -> to_:string -> ride option
(** The ride between two floors as the panel names them; [None] when no one
    panel has both (EXIT is no floor). The names pick the lift: B1F..B4F the
    hideout's, 1F..5F the store's. *)

val ride_of_args :
  Grid_maps.Json_field.obj -> (ride, Story.Failure.cause) result
(** A ["lift_floor"] action's ["from"] and ["to"]; [bad_args] otherwise. *)

type presses = { direction : Grid_maps.Direction.t; count : int }

val menu_presses : ride -> presses
(** The fewest D-pad presses that move the cursor from [from] to [to_]. A
    multichoice of more than three rows wraps round (pokefirered
    DrawVerticalMultichoiceMenu()); on a tie the cursor goes down. *)

val arrival : ride -> Story.Pose.observed
(** Where the ride leaves the player: [to_]'s exit. *)

val dim_warp_change : float
(** How far (the three channels' summed change) the middle of the screen moves
    from before the step out of the lift for the scene to count as gone: 30. *)

val ride : log:(string -> unit) -> ride -> unit
(** From below the lift door, facing north: into the lift, to the panel, the
    floor picked, the ride settled, and out a tile south of the floor's lift
    door. Fails as [no_warp_fade], [fade_stuck] or [lift_scene_stuck], or as the
    settle's cause. *)
