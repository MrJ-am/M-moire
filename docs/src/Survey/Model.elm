module Survey.Model exposing (Answer, Point, Production, Question, answer, axes, complete, decodeAnswer, decodeQuestion, encodeAnswer, encodePoint, move, point, touchAxis)

import Dict exposing (Dict)
import Json.Decode as D
import Json.Encode as E


type alias Point =
    { x : Float, y : Float, z : Float }


type alias Answer =
    { note : Maybe Float, initialNote : Maybe Float, point : Point, judged : List String }


type alias Production =
    { id : String, content : String }


type alias Question =
    { id : String, level : String, domain : String, statement : String, productions : List Production }


point : Point
point =
    Point 0 0 0


answer : Answer
answer =
    Answer Nothing Nothing point []


axes : List ( String, String, String )
axes =
    [ ( "x", "Confus", "Lisible" ), ( "y", "Vague", "Précis" ), ( "z", "Fautif", "Valide" ) ]


{-| Only the requested coordinate can change, independently of the renderer.
-}
move : String -> Float -> Point -> Point
move axis value previous =
    let
        bounded =
            clamp -10 10 value
    in
    case axis of
        "x" ->
            { previous | x = bounded }

        "y" ->
            { previous | y = bounded }

        "z" ->
            { previous | z = bounded }

        _ ->
            previous


touchAxis : String -> List String -> List String
touchAxis axis previous =
    if List.member axis [ "x", "y", "z" ] && not (List.member axis previous) then
        axis :: previous

    else
        previous


complete : Dict String Answer -> Question -> Bool
complete answers question =
    List.all (\p -> Dict.get p.id answers |> Maybe.map (\a -> a.note /= Nothing && List.length a.judged == 3) |> Maybe.withDefault False) question.productions


decodeQuestion : D.Decoder Question
decodeQuestion =
    D.map5 Question
        (D.field "id" D.string)
        (D.field "level" D.string)
        (D.field "domain" D.string)
        (D.field "statement" D.string)
        (D.field "productions" (D.list (D.map2 Production (D.field "id" D.string) (D.field "content" D.string))))


encodePoint : Point -> E.Value
encodePoint p =
    E.object [ ( "x", E.float p.x ), ( "y", E.float p.y ), ( "z", E.float p.z ) ]


decodeAnswer : D.Decoder Answer
decodeAnswer =
    D.map4 Answer
        (D.field "note" (D.nullable D.float))
        (D.field "initialNote" (D.nullable D.float))
        (D.field "coordinates" (D.map3 Point (D.field "x" D.float) (D.field "y" D.float) (D.field "z" D.float)))
        (D.field "evaluatedAxes" (D.list D.string))


encodeAnswer : Answer -> E.Value
encodeAnswer a =
    E.object
        [ ( "note", Maybe.map E.float a.note |> Maybe.withDefault E.null )
        , ( "initialNote", Maybe.map E.float a.initialNote |> Maybe.withDefault E.null )
        , ( "coordinates", encodePoint a.point )
        , ( "evaluatedAxes", E.list E.string a.judged )
        ]
