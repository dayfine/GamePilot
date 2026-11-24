let red_blue_min = 200
let green_min = 212
let brightest = 255

let ink : Wire.color_range =
  {
    min = (red_blue_min, green_min, red_blue_min);
    max = (brightest, brightest, brightest);
  }

let max_score = 0.125
let max_digits = 3
let min_level = 2
let max_level = 100

let of_digits = function
  | Some level when min_level <= level && level <= max_level -> Some level
  | _ -> None

let read glyphs =
  of_digits
    (Number_reading.read_left_aligned ~max_score ~ink glyphs
       Text_lines.summary_level_digit ~max_cells:max_digits)
