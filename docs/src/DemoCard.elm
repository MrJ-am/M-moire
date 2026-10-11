port module DemoCard exposing (main)

import Browser
import Browser.Events
import Element as Interface
import Html exposing (Html)
import Json.Decode as Decode
import MrJam
import MrJam.Ecran as Ecran
import MrJam.TableSpatiale as Table
import MrJam.Transitions as T
import Presentation as P
import Time


port reductionAnimations : (Bool -> message) -> Sub message


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
    { zoomTimeline : T.Transition ZoomState
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
    | TransitionTick Time.Posix
    | ReduireAnimations Bool


main : Program Bool Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : Bool -> ( Model, Cmd Msg )
init reduite =
    ( { zoomTimeline = T.initialiser Mini |> T.reduire reduite
      , cardX = 0.5
      , cardY = 0.5
      , dragging = Nothing
      , viewportWidth = 1200
      , viewportHeight = 800
      , suppressNextOpen = False
      }
    , Ecran.initiale (\ecran -> WindowResized ecran.largeur ecran.hauteur)
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ T.abonnement TransitionTick model.zoomTimeline
        , reductionAnimations ReduireAnimations
        , Browser.Events.onMouseMove mouseMoveDecoder
        , Browser.Events.onMouseUp (Decode.succeed GlobalMouseUp)
        , Browser.Events.onResize WindowResized
        ]


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

        TransitionTick now ->
            ( { model | zoomTimeline = T.mettreAJour now model.zoomTimeline }, Cmd.none )

        ReduireAnimations reduite ->
            ( { model | zoomTimeline = T.reduire reduite model.zoomTimeline }, Cmd.none )


animateZoom : ZoomState -> T.Transition ZoomState -> T.Transition ZoomState
animateZoom target timeline =
    T.aller 220 target timeline


view : Model -> Html Msg
view model =
    let
        dimensions =
            { largeur = model.viewportWidth - 24, hauteur = model.viewportHeight - 24 }

        echelle =
            T.nombre
                (\etat ->
                    if etat == Maxi then
                        1

                    else
                        0.25
                )
                model.zoomTimeline

        largeur =
            min 1100 (toFloat model.viewportWidth * 0.94)

        hauteur =
            min (toFloat model.viewportHeight * 0.92)
                (if model.viewportWidth < 600 then
                    360

                 else
                    240
                )
    in
    Table.cadre P.marque
        { largeur = model.viewportWidth, hauteur = model.viewportHeight }
        [ Table.plan dimensions
            Nothing
            (model.dragging /= Nothing)
            GlobalMouseMove
            GlobalMouseUp
            Close
            [ ( "demo"
              , Table.carte
                    { repere = "demo"
                    , x = model.cardX * toFloat dimensions.largeur
                    , y = model.cardY * toFloat dimensions.hauteur
                    , largeur = largeur
                    , hauteur = hauteur
                    , echelle = echelle
                    , ouverte = T.courant model.zoomTimeline == Maxi
                    , mouvement = T.actif model.zoomTimeline
                    , commencer = StartDrag
                    , ouvrir = Open
                    , fermer = Close
                    , contenu =
                        P.commun.section "Proposition A"
                            [ MrJam.paragraphe "On part de cos(2x) = sin(x), puis on écrit 1 - 2sin²(x) = sin(x)."
                            , MrJam.paragraphe "On obtient 2sin²(x) + sin(x) - 1 = 0, puis (2sin(x)-1)(sin(x)+1)=0."
                            , MrJam.paragraphe "Solutions sur [0;2π[ : x = π/6, 5π/6, 3π/2."
                            , P.commun.texteSecondaire "Cliquer sur la fiche pour agrandir. Cliquer ailleurs pour réduire. Maintenir et glisser pour déplacer."
                            ]
                    }
              )
            ]
        ]


mouseMoveDecoder : Decode.Decoder Msg
mouseMoveDecoder =
    Decode.map2 GlobalMouseMove
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
