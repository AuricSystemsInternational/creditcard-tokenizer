-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


port module Detokenizer exposing (..)

import Auv exposing (..)
import DetokenizerApi as DTA exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Encode as JE exposing (..)
import Navigation exposing (..)
import Time exposing (Time, second)


type alias Model =
    { sessionID : Maybe String
    , auvToken : Maybe String
    , decryptedToken : Maybe String
    , currentTime : Time
    , decryptOnTick : Bool -- so that attempt is made to get token when valid time available
    , location : Location
    }


type alias Flags =
    { sessionID : Maybe String
    , auvToken : Maybe String
    }


type Msg
    = LogErr String
    | DetokenizeResponse (Result Http.Error DetokenizeResponsePayload)
    | Tick Time
    | NoOp


initModel : Maybe String -> Maybe String -> Location -> Model
initModel sessionID auvToken location =
    { sessionID = sessionID
    , auvToken = auvToken
    , decryptedToken = Nothing
    , currentTime = 0
    , decryptOnTick = True
    , location = location
    }


init : Flags -> Location -> ( Model, Cmd Msg )
init { sessionID, auvToken } location =
    let
        model =
            initModel sessionID auvToken location
    in
    ( model, Cmd.none )



--        onDetokenize model


onDetokenize : Model -> ( Model, Cmd Msg )
onDetokenize model =
    let
        updatedModel =
            { model | decryptOnTick = False }
    in
    if model.auvToken == Nothing then
        ( updatedModel, DTA.sendMessageOut (DTA.LogError "Missing token") )
    else if model.sessionID == Nothing then
        ( updatedModel, DTA.sendMessageOut (DTA.LogError "Missing session ID") )
    else
        let
            contentBody =
                JE.object
                    [ ( "sessionId", JE.string (Maybe.withDefault "" model.sessionID) ) -- TODO: revisit
                    , ( "utcTimestamp", JE.string (toString model.currentTime) )
                    , ( "token", JE.string (Maybe.withDefault "" model.auvToken) )
                    ]

            body =
                JE.object
                    [ ( "id", JE.int 1 ) -- TODO: Use more appropriate id
                    , ( "method", JE.string "session_decrypt" )
                    , ( "params", JE.list [ contentBody ] )
                    ]
                    |> JE.encode 4
                    |> Http.stringBody "application/json"

            headers =
                []

            decoder =
                deTokenizeResponsePayloadDecoder

            url =
                vault_url model.location

            request =
                post url headers body decoder

            cmd =
                Http.send DetokenizeResponse request
        in
        ( updatedModel, cmd )


onDetokenizeResponseSuccess : Model -> DetokenizeResponsePayload -> ( Model, Cmd Msg )
onDetokenizeResponseSuccess model payload =
    let
        --        _ =
        --            payload |> Debug.log "PAYLOAD: "
        plainTextValue =
            payload.result.plaintextValue

        possibleError =
            payload.error

        requestFailed =
            payload.result.lastActionSucceeded /= 1
    in
    if requestFailed then
        ( model, onDetokenizeFail possibleError )
    else
        ( { model | decryptedToken = Just plainTextValue }, DTA.sendMessageOut Auv_Decrypted )


onDetokenizeFail : String -> Cmd msg
onDetokenizeFail err =
    let
        errCodeMessage =
            err |> String.split ":"

        errCode =
            if List.length errCodeMessage == 1 then
                ""
            else
                errCodeMessage
                    |> List.head
                    |> Maybe.withDefault ""

        -- error message is either the 2nd part of the error or the whole message
        errMessage =
            errCodeMessage
                |> List.tail
                |> Maybe.withDefault []
                |> List.head
                |> Maybe.withDefault ""
    in
    DTA.sendMessageOut (DTA.Auv_Error errCode errMessage)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LogErr err ->
            ( model, DTA.sendMessageOut (DTA.LogError err) )

        DetokenizeResponse (Ok payload) ->
            onDetokenizeResponseSuccess model payload

        DetokenizeResponse (Err err) ->
            ( model, onDetokenizeFail (toString err) )

        Tick newTime ->
            let
                updatedModel =
                    { model | currentTime = newTime }
            in
            if model.decryptOnTick == True then
                onDetokenize updatedModel
            else
                ( updatedModel, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every Time.second Tick
        ]


view : Model -> Html Msg
view model =
    div [ class "asi-deTokenizerRoot" ]
        [ label [] [ text "" ]
        , div [ class "asi-decryptedToken" ]
            [ text <|
                case model.decryptedToken of
                    Nothing ->
                        ""

                    Just val ->
                        val
            ]
        ]


locationToMsg : Location -> Msg
locationToMsg location =
    -- no need to do anything
    NoOp


main : Program Flags Model Msg
main =
    Navigation.programWithFlags locationToMsg
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
