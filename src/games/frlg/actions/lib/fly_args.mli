type request = {
  town : Fly_towns.town;
  user : Fly_user.user option;
      (** The plan's ["slot"] and ["menu_row"] (default 2); [None] when it gives
          no slot, and the first member that knows Fly flies ({!Fly_user.read}).
      *)
}

val decode : Json_field.obj -> (request, string) result
(** A ["fly"] action's args: ["town"] (a town of {!Fly_towns.load}) and,
    optionally, the Fly user's ["slot"] (from 1) and ["menu_row"]. *)

val plan : request -> Fly_user.user -> Fly.plan
(** The Fly to the request's town by this user. *)
