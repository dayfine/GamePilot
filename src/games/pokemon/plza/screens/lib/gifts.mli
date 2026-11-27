(** PLZA's Mystery Gift menu tree as a {!Screen_graph.Graph.t} (design:
    [docs/design/Screen-Graph.md]).

    Covers the main menu's six rows, the Mystery Gift menu, the Internet gift
    list, a received gift's card, the "stop receiving?" and "disconnect?" Yes/No
    questions, message boxes (such as "disconnected"), and the code keyboard.
    Link Play and the connecting screen have no reader yet: the graph declares
    [when_unread = Press B] (safe here because B opens at worst a question whose
    highlighted answer the walk then reads) and uses the five-press Link Play
    sequence on the edge from [Main_menu 5] to [Gift_menu]. *)

type answer = Plza_readers.Mystery_gift_screen.answer
(** A Yes/No question's highlighted answer. *)

(** The screens of PLZA's Mystery Gift menu tree. *)
type screen =
  | Main_menu of int
      (** Main menu with row [0..5] highlighted (5 = Link Play). *)
  | Gift_menu  (** Mystery Gift menu with "Get with Internet" highlighted. *)
  | Gift_list of int
      (** Active Internet gift list with item [0..5] selected. *)
  | Card  (** A received gift's card. *)
  | Stop_receiving of answer
      (** "Stop receiving?" question over the gift list. *)
  | Disconnect of answer
      (** "Disconnect?" question over the Mystery Gift menu. *)
  | Message  (** A message box with no question, card, or gift list under it. *)
  | Keyboard
      (** Switch code-entry keyboard opened from "Get with Code/Password". *)

val is_main_menu : screen -> bool
(** [true] for [Main_menu _]. *)

val is_gift_list : screen -> bool
(** [true] for [Gift_list _]. *)

val show : screen -> string
(** Human-readable name of a screen. *)

val read : Wire.frame -> screen list
(** Candidate screens for a frame (empty when unread, e.g. Link Play or a fade).
*)

val graph :
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  gift_name:string option ->
  screen Screen_graph.Graph.t
(** The Mystery Gift screen graph with its full probe list for [picture]. *)

val walk_graph : screen Screen_graph.Graph.t
(** The same graph with [probes = []], for callers (such as [Leave_gifts]) that
    already run inside [Mystery_gift.probes]. *)
