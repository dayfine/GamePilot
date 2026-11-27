(** From any Mystery Gift screen back to the main menu, walking
    {!Plza_screens.Gifts} via {!Screen_graph.Screen_walk.go_to} (design:
    [docs/design/Screen-Graph.md]).

    A is pressed only on a question read with Yes highlighted ("stop receiving?"
    over the gift list, "disconnect?" over the Mystery Gift menu) or on a
    message read with no gift list under it (as "disconnected"): never on the
    gift list itself. Unread screens (such as Link Play) receive at most three
    consecutive B presses ({!Screen_graph.Screen_walk.max_unread_presses}),
    logged on every use. *)

val to_main_menu : log:(string -> unit) -> (unit, string) result
(** Walk {!Plza_screens.Gifts.walk_graph} to any main menu row (at most 12
    hops); [Error] with the failure details and last reading otherwise. The
    probes must already be subscribed ({!Mystery_gift.probes}). *)
