port module Administration exposing (main)

{-| Écran de connexion. Les sessions, l’activation et les permissions restent
à la charge du serveur et du pont HTTP existants, jamais de la bibliothèque.
-}

import Browser
import Element as Interface
import Html exposing (Html)
import Html.Events
import Json.Decode as Decoder
import MrJam exposing (avis, bouton, boutonEnCours, champ, lien, motDePasse, page, section, texteSecondaire)


port connexion : { username : String, password : String } -> Cmd message


port retourConnexion : (String -> message) -> Sub message


type alias Modele =
    { identifiant : String
    , secret : String
    , erreur : String
    , enCours : Bool
    }


type Message
    = ModifierIdentifiant String
    | ModifierSecret String
    | SeConnecter
    | Refus String


main : Program () Modele Message
main =
    Browser.element
        { init = \_ -> ( Modele "admin" "" "" False, Cmd.none )
        , update = actualiser
        , view = afficher
        , subscriptions = \_ -> retourConnexion Refus
        }


actualiser : Message -> Modele -> ( Modele, Cmd Message )
actualiser message modele =
    case message of
        ModifierIdentifiant valeur ->
            ( { modele | identifiant = valeur }, Cmd.none )

        ModifierSecret valeur ->
            ( { modele | secret = valeur }, Cmd.none )

        Refus explication ->
            ( { modele | enCours = False, erreur = explication }, Cmd.none )

        SeConnecter ->
            if modele.enCours then
                ( modele, Cmd.none )

            else if String.length modele.identifiant < 3 || String.length modele.identifiant > 80 then
                ( { modele | erreur = "L’identifiant doit comporter de 3 à 80 caractères." }, Cmd.none )

            else if String.isEmpty modele.secret || String.length modele.secret > 256 then
                ( { modele | erreur = "Saisissez un mot de passe de 1 à 256 caractères." }, Cmd.none )

            else
                ( { modele | enCours = True, erreur = "" }
                , connexion { username = modele.identifiant, password = modele.secret }
                )


validerAuClavier : Decoder.Decoder ( Message, Bool )
validerAuClavier =
    Decoder.map2 Tuple.pair
        (Decoder.field "key" Decoder.string)
        (Decoder.at [ "target", "tagName" ] Decoder.string)
        |> Decoder.andThen
            (\( touche, cible ) ->
                if touche == "Enter" && cible == "INPUT" then
                    Decoder.succeed ( SeConnecter, True )

                else
                    Decoder.fail "Pas une validation de saisie"
            )


afficher : Modele -> Html Message
afficher modele =
    page "Matheval · Administration"
        [ Interface.el
            [ Interface.width Interface.fill
            , Interface.htmlAttribute (Html.Events.preventDefaultOn "keydown" validerAuClavier)
            ]
            (section "Retrouver les regards."
                [ texteSecondaire "Connectez-vous pour consulter le corpus et les réponses des enseignants."
                , champ "Identifiant" modele.identifiant ModifierIdentifiant
                , motDePasse "Mot de passe" modele.secret ModifierSecret
                , if modele.erreur == "" then
                    Interface.none

                  else
                    avis MrJam.Erreur modele.erreur
                , if modele.enCours then
                    boutonEnCours "Connexion en cours…"

                  else
                    bouton "Se connecter" SeConnecter
                , lien "Accéder au questionnaire" "../"
                ]
            )
        ]
