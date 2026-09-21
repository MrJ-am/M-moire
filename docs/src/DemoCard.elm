module DemoCard exposing (main)

import Animator
import Animator.Inline
import Browser
import Browser.Events
import Element as Interface
import Html exposing (Html, div, h2, p, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick, preventDefaultOn, stopPropagationOn)
import Json.Decode as Decode
import MrJam
import MrJam.Disposition as Disposition
import Time


type ZoomState
    = Mini
    | Maxi


type alias DragState =
    { startMouseX : Float
    , startMouseY : Float
    , startCardX : Float
    , startCardY : Float
    , moved : Bool
    }


type alias Model =
    { zoomTimeline : Animator.Timeline ZoomState
    , cardX : Float
    , cardY : Float
    , dragging : Maybe DragState
    , viewportWidth : Int
    , viewportHeight : Int
    , suppressNextOpen : Bool
    }


type Msg
    = Open
    | Close
    | StartDrag Float Float
    | GlobalMouseMove Float Float
    | GlobalMouseUp
    | WindowResized Int Int
    | AnimatorTick Time.Posix


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { zoomTimeline = Animator.init Mini
      , cardX = 0.5
      , cardY = 0.5
      , dragging = Nothing
      , viewportWidth = 1200
      , viewportHeight = 800
      , suppressNextOpen = False
      }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Animator.toSubscription AnimatorTick model animator
        , Browser.Events.onMouseMove mouseMoveDecoder
        , Browser.Events.onMouseUp (Decode.succeed GlobalMouseUp)
        , Browser.Events.onResize WindowResized
        ]


animator : Animator.Animator Model
animator =
    Animator.animator
        |> Animator.watching .zoomTimeline
            (\newZoom currentModel ->
                { currentModel | zoomTimeline = newZoom }
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Open ->
            if model.suppressNextOpen then
                ( { model | suppressNextOpen = False }, Cmd.none )

            else
                ( { model | zoomTimeline = animateZoom Maxi model.zoomTimeline }, Cmd.none )

        Close ->
            ( { model | zoomTimeline = animateZoom Mini model.zoomTimeline }, Cmd.none )

        StartDrag mouseX mouseY ->
            ( { model
                | dragging =
                    Just
                        { startMouseX = mouseX
                        , startMouseY = mouseY
                        , startCardX = model.cardX
                        , startCardY = model.cardY
                        , moved = False
                        }
                , suppressNextOpen = False
              }
            , Cmd.none
            )

        GlobalMouseMove mouseX mouseY ->
            case model.dragging of
                Nothing ->
                    ( model, Cmd.none )

                Just dragState ->
                    let
                        widthFloat =
                            max 1 (toFloat model.viewportWidth)

                        heightFloat =
                            max 1 (toFloat model.viewportHeight)

                        deltaX =
                            (mouseX - dragState.startMouseX) / widthFloat

                        deltaY =
                            (mouseY - dragState.startMouseY) / heightFloat

                        nextX =
                            clamp 0.08 0.92 (dragState.startCardX + deltaX)

                        nextY =
                            clamp 0.08 0.92 (dragState.startCardY + deltaY)

                        movedNow =
                            dragState.moved || distance dragState.startMouseX dragState.startMouseY mouseX mouseY > 4
                    in
                    ( { model
                        | cardX = nextX
                        , cardY = nextY
                        , dragging = Just { dragState | moved = movedNow }
                      }
                    , Cmd.none
                    )

        GlobalMouseUp ->
            case model.dragging of
                Nothing ->
                    ( model, Cmd.none )

                Just dragState ->
                    ( { model
                        | dragging = Nothing
                        , suppressNextOpen = dragState.moved
                      }
                    , Cmd.none
                    )

        WindowResized width height ->
            ( { model | viewportWidth = width, viewportHeight = height }, Cmd.none )

        AnimatorTick now ->
            ( Animator.update now animator model, Cmd.none )


animateZoom : ZoomState -> Animator.Timeline ZoomState -> Animator.Timeline ZoomState
animateZoom target timeline =
    Animator.go (Animator.millis 220) target timeline


view : Model -> Html Msg
view model =
    Disposition.cadre [ Interface.htmlAttribute (style "height" "100vh"), Interface.htmlAttribute (onClick Close) ]
        (Interface.html (viewCard model))


viewCard : Model -> Html Msg
viewCard model =
    let
        cursorStyle =
            if model.dragging /= Nothing then
                "grabbing"

            else
                "grab"
    in
    div
        [ preventDefaultOn "mousedown"
            (Decode.map
                (\( x, y ) -> ( StartDrag x y, True ))
                mousePointDecoder
            )
        , stopPropagationOn "click" (Decode.succeed ( Open, True ))
        , style "position" "absolute"
        , style "left" (String.fromFloat (model.cardX * 100) ++ "%")
        , style "top" (String.fromFloat (model.cardY * 100) ++ "%")
        , Animator.Inline.scale model.zoomTimeline
            (\zoom ->
                case zoom of
                    Mini ->
                        Animator.at 0.25 |> Animator.arriveSmoothly 0.75

                    Maxi ->
                        Animator.at 1 |> Animator.arriveSmoothly 0.75
            )
        , style "transform-origin" "center center"
        , style "width" "min(1100px, 94vw)"
        , style "max-height" "92vh"
        , style "overflow" "auto"
        , style "cursor" cursorStyle
        , style "user-select" "none"
        ]
        [ Disposition.fragment
            (MrJam.section "Proposition A"
                [ MrJam.paragraphe "On part de cos(2x) = sin(x), puis on écrit 1 - 2sin²(x) = sin(x)."
                , MrJam.paragraphe "On obtient 2sin²(x) + sin(x) - 1 = 0, puis (2sin(x)-1)(sin(x)+1)=0."
                , MrJam.paragraphe "Solutions sur [0;2π[ : x = π/6, 5π/6, 3π/2."
                , MrJam.texteSecondaire "Cliquer sur la fiche pour agrandir. Cliquer ailleurs pour réduire. Maintenir et glisser pour déplacer."
                ]
            )
        ]


mouseMoveDecoder : Decode.Decoder Msg
mouseMoveDecoder =
    Decode.map2 GlobalMouseMove
        (Decode.field "clientX" Decode.float)
        (Decode.field "clientY" Decode.float)


mousePointDecoder : Decode.Decoder ( Float, Float )
mousePointDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "clientX" Decode.float)
        (Decode.field "clientY" Decode.float)


distance : Float -> Float -> Float -> Float -> Float
distance x1 y1 x2 y2 =
    sqrt (((x2 - x1) ^ 2) + ((y2 - y1) ^ 2))


clamp : Float -> Float -> Float -> Float
clamp minVal maxVal value =
    if value < minVal then
        minVal

    else if value > maxVal then
        maxVal

    else
        value
