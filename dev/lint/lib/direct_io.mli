(** Flags direct I/O and concurrency module usage inside game programs and
    actions (A1). Programs must use the effect set rather than calling I/O
    libraries directly. *)

val in_scope : string -> bool
(** [in_scope path] is true when [path] is under a game's [programs/] or
    [actions/] tree (e.g. [src/games/.../programs/.../lib/*.ml] or
    [src/games/.../actions/.../lib/*.ml]). *)

val check : Parsed_source.t -> Finding.t list
(** Reports references to [Unix], [Thread], [Domain], [Eio], [Lwt], [In_channel]
    or [Out_channel] in [src]. *)
