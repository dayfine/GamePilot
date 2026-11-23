val decode :
  Party_roster.t -> Grid_maps.Json_field.obj -> (Fly.plan, string) result
(** A ["fly"] action's args: ["town"] (a town of {!Fly_towns.load}), the Fly
    user as ["slot"] (from 1) or ["species"] (found in the party), and
    ["menu_row"] (default 2). *)
