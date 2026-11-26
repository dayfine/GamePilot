(** {!Claim_gifts}' steps on the live game, in the effect context: the main
    menu, {!Gift_claim}, {!Gift_boxes} and {!Save_progress}, each with the
    Mystery Gift probes subscribed while it runs ({!Mystery_gift.probes}). *)

val name_template : id:string -> language:string -> string
(** The repo path of an Internet gift's name template in a language (a tag of
    [--options language=]):
    [src/games/pokemon/plza/assets/gift-name-<id>-<language>.png], the name as
    an unselected list item shows it ({!Plza_readers.Mystery_gift_screen}). *)

val game_steps :
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  name_templates:(string * string) list ->
  Claim_gifts.game_steps
(** The steps over the game picture at [picture], with the PLZA readers'
    uploaded templates. [name_templates]: each Internet gift's name template in
    the game's language, by gift id, as PNG bytes; uploaded when its gift is
    claimed. *)

val actions :
  catalog:Plza_gift_catalog.Gift_catalog.t ->
  today:Plza_gift_catalog.Gift_catalog.date ->
  name_templates:(string * string) list ->
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  (string * Plza_engine.Game.game_action) list
(** The program's game actions ({!Claim_gifts.game_actions}) over these steps,
    for one run's session: a new {!Claim_gifts.run} of the catalog on [today].
*)
