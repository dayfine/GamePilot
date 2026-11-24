(** The input lease (protocol/v1, v1.9): one connection at a time may send input
    ([submit], [cancel], [backend.load_state]). A connection takes it with
    [lease.acquire] or its first input; it ends on disconnect, [lease.release],
    or [ttl_ms] with no input. Anyone else's input is refused with {!held_code},
    naming the holder. *)

type json = Yojson.Safe.t

type t = {
  owner : string;  (** the label [lease.acquire] gave, or the [hello] name *)
  client : string;  (** the holder's [hello] name; empty before [hello] *)
  held_ms : int;  (** how long it has held the lease *)
  ttl_ms : int;  (** how long it may go without input *)
}

val of_json : json -> t
val to_json : t -> json

val acquire_result_of_json : json -> t
(** The [lease.acquire] result: the lease now held. *)

val json_of_acquire_result : t -> json

val release_result_of_json : json -> bool
(** Whether the connection held the lease it released. *)

val json_of_release_result : bool -> json

val held_code : int
(** -32004: the error code of input refused because another connection holds the
    lease. *)

val refusal : Jsonrpc.error -> t option
(** The holder a lease refusal names; [None] for any other error. *)

val describe : t -> string
(** One line for a person: owner, client when it differs, how long held. *)
