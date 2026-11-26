(** The game actions of mg-06, which uses the Mail Glitch (spec:
    docs/mail-glitch-use.md, decisions on PR #52): the party's marks checked,
    the glitched mail read (proof A), an item moved to its pocket's top, and the
    item duplication ({!Item_duplication}, proof B).

    - ["check_party_marks"], args ["marks"]: one per slot from 1, ["held_item"],
      ["mail"] or ["none"]. The party opened, read after the fork's 800 ms
      ({!Party_actions.party_settle_ms}), each slot's mark compared, the party
      closed through its fade ({!Menu_input.close_through_fades}). As the fork's
      Mail Glitch check (Programs/MailGlitch/PokemonFRLG_MailGlitchActions.cpp)
      does, for every slot. Fails as [party_marks_wrong].
    - ["read_glitched_mail"], args ["species"] or ["target_slot"], ["word"]:
      Retro Mail given to the member (as {!Party_actions.give} until the switch
      question, answered YES), the editor's field 1 read
      ({!Frlg_text.Mail_fields}, that frame kept in the run folder as
      [proof-a.png]), and only if it reads ["word"], PLUS and YES (the exit of
      the fork's Programs/Farming/PokemonFRLG_ItemDuplication.cpp) back to the
      bag, closed through the fades ({!Menu_input.close_through_fades}). Fails
      as [mail_glitch_not_active] without confirming anything. Not in the fork.
    - ["move_item_to_top"], args ["item"]: in the item's pocket, SELECT on it,
      UP to the list's top (counted: the cursor hides while the item moves),
      SELECT (pokefirered item_menu.c, [BeginMovingItemInPocket] and
      [Task_MoveItemInPocket_HandleInput]); then the item must read on the top
      row. Nothing is pressed when it is there. Fails as [item_not_on_top]. Not
      in the fork: its PokemonFRLG_ItemDuplication.cpp asks the player to do it.
    - ["duplicate_item"], args ["species"] or ["target_slot"] (party slot 1, the
      C++'s), ["item"], ["count"], ["word"]: {!Item_duplication.run}. *)

val mark_of_name : string -> Frlg_readers.Party_menu.mark option
(** ["held_item"], ["mail"], ["none"]. *)

val name_of_mark : Frlg_readers.Party_menu.mark -> string
(** The inverse of {!mark_of_name}: a plan's name for the mark. *)

val read_marks : log:(string -> unit) -> Frlg_readers.Party_menu.mark list
(** The party opened, read after {!Party_actions.party_settle_ms}, each member's
    mark from slot 1 ({!Frlg_readers.Party_menu.members} of them), the party
    closed through its fade ({!Menu_input.close_through_fades}):
    [check_party_marks]'s read, also the [marks] postcondition's. *)

val marks_mismatch :
  Frlg_readers.Party_menu.mark list ->
  read:(int -> Frlg_readers.Party_menu.mark) ->
  string option
(** [None] when slot [i] (from 1) reads the [i]-th mark; else the first slot
    that does not: ["slot 2 shows none, not mail"]. *)

val duplication_plan : where:string -> Json_field.obj -> Item_duplication.plan
(** ["duplicate_item"]'s args: ["item"], ["count"] (rounds) and ["word"]. *)

val handlers :
  log:(string -> unit) ->
  party:Party_roster.t ref ->
  (string * Pokemon_engine.Game.game_action) list
(** The four actions above, by name. *)
