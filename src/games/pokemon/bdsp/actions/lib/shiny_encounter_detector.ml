module R = Bdsp_readers.Shiny_encounter_reader

let default_timeout_ms = 30_000

let advance_frame state frame =
  let next = R.step ~frame !state in
  state := next;
  R.is_finished next

let watch ~timeout_ms state () =
  ignore (Effects.await ~timeout_ms (advance_frame state) : Effects.awaited)

let detect ~picture ?(timeout_ms = default_timeout_ms)
    ?(thresholds = R.default_thresholds) () =
  let state = ref R.init in
  Effects.with_probes (R.probes ~picture) (watch ~timeout_ms state);
  R.classify ~thresholds !state
