let id = "interact_prompt"

let area =
  Native_box.of_fractions { left = 0.3; top = 0.2; width = 0.4; height = 0.65 }

let probes_over ~picture ~assets ~id area =
  Button_detector.probe ~picture ~assets ~id A area

let shown_over m id = Button_detector.shown m id A
let probes ~picture ~assets = probes_over ~picture ~assets ~id area
let shown m = shown_over m id
