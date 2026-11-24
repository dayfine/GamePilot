(** Each party member as the room policy ({!Story.Room_policy}) and the
    pre-flight's field-move check need it: its species and level on the
    summary's POKéMON INFO page and its moves on the KNOWN MOVES page, one
    summary opening per member. The pages are read as {!Party_species},
    {!Member_level} and {!Summary_moves} read them (the fork's
    [read_party_summary()] in Programs/AutoStory/PokemonFRLG_AutoStorySummary,
    [frlg/lean], reads species and level the same way; its moves reader is
    PokemonFRLG_SummaryMovesReader). *)

val read_member : log:(string -> unit) -> int -> Story.Room_policy.member
(** From the overworld: the member in this slot (from 1). A page that does not
    settle leaves its part [None] ([species] ["?"]). Logs
    ["Party: slot 2 is eevee Lv 25 (tackle, ...)."]. Fails as [no_party],
    [no_member_menu] or [no_summary]. *)

val read_all : log:(string -> unit) -> unit -> Story.Room_policy.member list
(** From the overworld: every member, as many as the party menu shows. Run it
    inside {!Menu_input.run}, whose probes it reads. *)
