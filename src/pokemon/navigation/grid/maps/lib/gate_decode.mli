(** Reading a map file's ["gates"] and ["switches"] tables (see {!Map_gates}).
    Both raise {!Json_field.Invalid} naming [where] (the file, as
    ["Test.json: "]) and the field; a table the map leaves out reads as empty.
    Whether the tiles they name fit the map is {!Map_checks}' job. *)

val gates : where:string -> Json_field.obj -> Map_gates.gate list
(** Each gate is a flag gate (["opens_by"] and ["flag"], closed at a new game)
    or follows a switch (["switch"] and ["open_when"], open at a new game
    exactly when it opens with the switch off), never both. Its ["open_glyph"]
    is one of [. ~ 2 4 6 8]. *)

val switches : where:string -> Json_field.obj -> Map_gates.switch list
(** A switch with ["toggle"] true (the default) has ["statues"]; one with
    ["toggle"] false has ["buttons"] and ["set_value"]. *)
