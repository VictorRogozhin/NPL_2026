open System
open System.IO
open System.Text
open System.Text.Json

let field (name: string) (element: JsonElement) =
    match element.ValueKind with
    | JsonValueKind.Object ->
        match element.TryGetProperty name with
        | true, value -> value
        | _ -> failwithf "Missing field '%s'" name
    | _ -> failwith "Expected a JSON object"

let requireType expected element =
    let actual = field "type" element
    if actual.ValueKind <> JsonValueKind.String || actual.GetString() <> expected then
        failwithf "Expected type '%s'" expected

let primitive name (value: JsonElement) =
    match value.ValueKind with
    | JsonValueKind.String -> value.GetString()
    | JsonValueKind.Number | JsonValueKind.True | JsonValueKind.False -> value.GetRawText()
    | JsonValueKind.Null -> ""
    | _ -> failwithf "Property '%s' must be a primitive" name

let point (feature: JsonElement) =
    requireType "Feature" feature
    let geometry = field "geometry" feature
    requireType "Point" geometry
    let coords = field "coordinates" geometry
    if coords.ValueKind <> JsonValueKind.Array || coords.GetArrayLength() <> 2 then
        failwith "Point must have exactly two coordinates"
    let coordinate (index: int) =
        let value = coords.[index]
        if value.ValueKind <> JsonValueKind.Number then failwith "Coordinate must be a number"
        value.GetRawText()
    let props = field "properties" feature
    let properties =
        match props.ValueKind with
        | JsonValueKind.Null -> Map.empty
        | JsonValueKind.Object ->
            props.EnumerateObject()
            |> Seq.fold (fun acc property ->
                let name = property.Name
                if name = "longitude" || name = "latitude" then
                    failwithf "Property '%s' conflicts with a coordinate column" name
                if Map.containsKey name acc then failwithf "Duplicate property '%s'" name
                Map.add name (primitive name property.Value) acc) Map.empty
        | _ -> failwith "Expected a properties object or null"
    coordinate 0, coordinate 1, properties

let escape (value: string) =
    if value.IndexOfAny([| ','; '"'; '\r'; '\n' |]) >= 0 then
        "\"" + value.Replace("\"", "\"\"") + "\""
    else value

let convert input output =
    use document = JsonDocument.Parse(File.ReadAllText input)
    let root = document.RootElement
    requireType "FeatureCollection" root
    let features = field "features" root
    if features.ValueKind <> JsonValueKind.Array then failwith "Expected an array of features"
    let rows =
        features.EnumerateArray()
        |> Seq.mapi (fun i feature ->
            try point feature
            with ex -> failwithf "Feature %d: %s" (i + 1) ex.Message)
        |> Seq.toArray
    let names =
        rows
        |> Seq.collect (fun (_, _, properties) -> properties |> Map.toSeq |> Seq.map fst)
        |> Set.ofSeq
        |> Set.toList
    let csvRow values = values |> List.map escape |> String.concat ","
    let lines = seq {
        yield csvRow ("longitude" :: "latitude" :: names)
        for lon, lat, properties in rows do
            let cells = names |> List.map (fun name -> Map.tryFind name properties |> Option.defaultValue "")
            yield csvRow (lon :: lat :: cells)
    }
    File.WriteAllText(output, String.concat "\r\n" lines + "\r\n", UTF8Encoding(false))
    printfn "Wrote %d point(s) to %s" rows.Length output

try
    match fsi.CommandLineArgs |> Array.skip 1 with
    | [| input; output |] -> convert input output
    | _ -> failwith "Usage: run.cmd [INPUT.geojson OUTPUT.csv]"
with ex ->
    eprintfn "Error: %s" ex.Message
    exit 1
