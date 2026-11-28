(** Host-side inputs read at the edge for PLZA's gift and HOME programs so
    neither reads a clock or a file itself: the gift catalog
    ({!Plza_gift_catalog.Gift_catalog}), today's date in UTC, each Internet
    gift's name template PNG bytes, and the guide's gifts table block. *)

val catalog : unit -> (Plza_gift_catalog.Gift_catalog.t, string) result
(** Locates and decodes PLZA's gift catalog ([gifts.json]) from the repo. *)

val today : unit -> Plza_gift_catalog.Gift_catalog.date
(** The host's current calendar date in UTC. *)

val name_templates :
  template_path:(id:string -> language:string -> string) ->
  language:string ->
  Plza_gift_catalog.Gift_catalog.t ->
  (string * string) list
(** Reads each Internet gift's name template PNG bytes in [language] when the
    file resolved by [template_path ~id ~language] exists in the repo. *)

val gifts_block : unit -> (string, string) result
(** Renders the gift catalog as a Markdown table for [plza.claim-gifts]' guide.
*)
