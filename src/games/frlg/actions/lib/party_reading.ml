type t = {
  log : string -> unit;
  roster : Party_roster.t ref;
  mutable known : bool;
}

let create ~log stated =
  {
    log;
    roster = ref (Option.value stated ~default:(Party_roster.of_list []));
    known = Option.is_some stated;
  }

let roster t = t.roster

(* From the overworld, back to it. *)
let read t =
  let species = ref [] in
  Result.map
    (fun () ->
      t.roster := Party_roster.of_read !species;
      t.known <- true;
      t.log
        ("Party: read " ^ String.concat ", " (Party_roster.to_list !(t.roster))))
    (Menu_input.run (fun () -> species := Party_species.read_all ~log:t.log))

let guard t (name, (handler : Story.Game.game_action)) =
  let run event args =
    if t.known || not (Action_args.picks_member ~action:name args) then
      handler event args
    else Result.bind (read t) (fun () -> handler event args)
  in
  (name, run)
