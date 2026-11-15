let cross (ax, ay) (bx, by) (px, py) =
  let open Int64 in
  sub (mul (sub bx ax) (sub py ay)) (mul (sub by ay) (sub px ax))

let side a b points =
  List.filter (fun p -> cross a b p > 0L) points

(* Produce the vertices strictly between a and b on their left side. *)
let rec chain a b = function
  | [] -> []
  | first :: rest as points ->
      let farther best p =
        let d = cross a b p and best_d = cross a b best in
        if d > best_d || (d = best_d && compare p best < 0) then p else best
      in
      let pivot = List.fold_left farther first rest in
      chain a pivot (side a pivot points)
      @ (pivot :: chain pivot b (side pivot b points))

let remove_collinear points =
  let ring = Array.of_list points in
  let n = Array.length ring in
  List.filteri (fun i p ->
    cross ring.((i + n - 1) mod n) p ring.((i + 1) mod n) <> 0L
  ) points

let quickhull points =
  match List.sort_uniq compare points with
  | [] -> []
  | [p] -> [p]
  | a :: rest ->
      let b = List.hd (List.rev rest) in
      let upper = chain a b (side a b rest) in
      let lower = chain b a (side b a rest) in
      let hull = a :: (upper @ (b :: lower)) in
      if upper = [] && lower = [] then hull else remove_collinear hull

let coordinate s =
  let n = Int64.of_string s in
  if n < -1_000_000_000L || n > 1_000_000_000L then
    failwith "Coordinates must be between -1000000000 and 1000000000";
  n

let read_points path =
  let input = open_in path in
  Fun.protect ~finally:(fun () -> close_in input) (fun () ->
    let rec read acc =
      match input_line input with
      | exception End_of_file -> List.rev acc
      | line ->
          let fields = String.split_on_char ' ' (String.trim line)
            |> List.filter (fun s -> s <> "") in
          match fields with
          | [] -> read acc
          | [x; y] -> read ((coordinate x, coordinate y) :: acc)
          | _ -> failwith "Expected two integer coordinates per line"
    in
    read [])

let () =
  try
    let path = if Array.length Sys.argv > 1 then Sys.argv.(1) else "data/points.txt" in
    let points = read_points path in
    let hull = quickhull points in
    Printf.printf "Input points: %d\nHull vertices: %d\n"
      (List.length points) (List.length hull);
    List.iter (fun (x, y) -> Printf.printf "(%Ld, %Ld)\n" x y) hull
  with Failure msg | Sys_error msg ->
    Printf.eprintf "Error: %s\n" msg;
    exit 1
