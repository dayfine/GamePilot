(** {!Claim_gifts}' steps on the live game, in the effect context: the main
    menu, {!Gift_claim}, {!Gift_boxes} and {!Save_progress}, each with the
    Mystery Gift probes subscribed while it runs ({!Mystery_gift.probes}). *)

val name_template : id:string -> language:string -> string
(** The repo path of an Internet gift's name template in a language (a tag of
    [--options language=]):
    [src/games/pokemon/plza/assets/gift-name-<id>-<language>.png], the name as
    an unselected list item shows it ({!Plza_readers.Mystery_gift_screen}). *)

val message_names : string list
(** The "received before" messages' template names: [gift-received-before] (an
    Internet gift's) and [code-used-before] (a code's). *)

val message_template : name:string -> language:string -> string
(** The repo path of such a template in a language:
    [src/games/pokemon/plza/assets/<name>-<language>.png]
    ({!Plza_readers.Received_before}). *)

val game_steps :
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  name_templates:(string * string) list ->
  message_templates:(string * string) list ->
  Claim_gifts.game_steps
(** The steps over the game picture at [picture], with the PLZA readers'
    uploaded templates. [name_templates]: each Internet gift's name template in
    the game's language, by gift id, as PNG bytes; uploaded when its gift is
    claimed. [message_templates]: the "received before" messages' templates that
    exist in the game's language, by name ({!message_names}), as PNG bytes;
    uploaded with each claim. *)

val game :
  catalog:Plza_gift_catalog.Gift_catalog.t ->
  today:Plza_gift_catalog.Gift_catalog.date ->
  name_templates:(string * string) list ->
  message_templates:(string * string) list ->
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  Plza_engine.Game.t
(** The engine's game for one attempt: {!Claim_gifts.game_actions} over these
    steps, on a new {!Claim_gifts.run} of the catalog on [today]. Any other
    event fails [no_handler]; the engine's save and reload fail [no_reload] (the
    program saves by its own action and never reloads). *)
