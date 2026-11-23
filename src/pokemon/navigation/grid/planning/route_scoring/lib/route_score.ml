type verdict = Pass | Fail | Strand | Retries

let verdict_name = function
  | Pass -> "PASS"
  | Fail -> "FAIL"
  | Strand -> "STRAND"
  | Retries -> "RETRIES"

type t = {
  verdict : verdict;
  why : string;
  nominal_ms : int;
  expected_ms : float;
  worst_ms : int;
  stops : int;
  presses : int;
  recoveries : int;
  replans : int;
}

let pass =
  {
    verdict = Pass;
    why = "";
    nominal_ms = 0;
    expected_ms = 0.;
    worst_ms = 0;
    stops = 0;
    presses = 0;
    recoveries = 0;
    replans = 0;
  }

let fail verdict why score =
  if score.verdict = Pass then { score with verdict; why } else score
