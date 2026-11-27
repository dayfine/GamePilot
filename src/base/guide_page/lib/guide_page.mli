(** A user guide page (docs/guide/) with generated blocks: hand-written Markdown
    around blocks that [gamepilot guide] writes from the code and the plans. A
    block is the lines between a start marker and an end marker, each a line of
    its own:

    {v
<!-- generated:NAME -->          or  <!-- generated:NAME ARG -->
...generated Markdown...
<!-- /generated -->
    v}

    NAME says what the block shows ([checkpoints], [needs], ...) and ARG, when
    given, which part ([01-celadon-setup..08-activate-and-verify]). Text outside
    the blocks is never touched. *)

type block = {
  name : string;
  arg : string option;
  body : string;  (** The lines between the markers, each ending in a newline. *)
}

val blocks : string -> (block list, string) result
(** The page's blocks in order; [Error] for a start marker with no end, an end
    with no start, or a start inside a block, naming its line. *)

val missing_blocks :
  required:string list -> string -> (string list, string) result
(** The names in [required] that no block of the page has, in [required]'s
    order; [Error] as {!blocks}. *)

val fill :
  (block -> (string, string) result) -> string -> (string, string) result
(** The page with each block's body replaced by what [generate] gives for it (a
    trailing newline is added when missing); the first error otherwise. *)

val start_marker : string -> string option -> string
(** ["<!-- generated:NAME ARG -->"], for a page's first draft. *)

val end_marker : string

val long_paragraphs : max_lines:int -> string -> (int * int) list
(** The hand-written paragraphs longer than [max_lines] lines, as each one's
    first line number and length. A list item counts as a paragraph of its own;
    blocks, code (fenced or indented), headings, tables and comments are not
    paragraphs. *)

val cell : string -> string
(** Text as a Markdown table cell: every pipe escaped, so none ends the cell. *)

val checkpoint_rows :
  load_title:(plan_dir:string -> string -> (string * string, string) result) ->
  plan_dir:string ->
  string list ->
  (string list, string) result
(** Formats one Markdown table row (["| <id> | <title> |"]) per checkpoint id in
    [ids], calling [load_title ~plan_dir id] for each checkpoint's id and title
    and escaping pipes via {!cell}. *)

val switch_testing_commands : args:string -> string
(** Formats the example Switch testing-mode [gamepilot run] command block for
    [args] ([PROGRAM --from ... --to ...]). *)
