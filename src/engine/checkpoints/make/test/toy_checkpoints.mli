(** The engine over the toy game ({!Toy_rules}, read by {!Toy_codec}, printed by
    {!Toy_text}, kept by {!Toy_saved}). *)

include module type of struct
  include Engine_checkpoints.Make (Toy_rules) (Toy_codec) (Toy_text) (Toy_saved)
end
