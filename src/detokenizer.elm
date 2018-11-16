-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


port module Detokenizer exposing (main)

import Auv exposing (..)
import Browser
import Browser.Navigation as Nav
import DetokenizerApi as DTA exposing (..)
import Helpers
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Encode as JE exposing (..)
import Time exposing (Posix)
import Url


type alias Model =
    { sessionID : Maybe String
    , auvToken : Maybe String
    , decryptedToken : Maybe String
    , currentTime : Posix
    , decryptOnTick : Bool -- so that attempt is made to get token when valid time available
    , location : Url.Url
    , key : Nav.Key
    , vaultTraceId : Maybe String
    }


type alias Flags =
    { sessionID : Maybe String
    , auvToken : Maybe String
    , vaultTraceId : Maybe String
    }


type Msg
    = LogErr String
    | DetokenizeResponse (Result Http.Error DetokenizeResponsePayload)
    | Tick Posix
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOp


initModel : Maybe String -> Maybe String -> Url.Url -> Nav.Key -> Maybe String -> Model
initModel sessionID auvToken location key traceId =
    { sessionID = sessionID
    , auvToken = auvToken
    , decryptedToken = Nothing
    , currentTime = Time.millisToPosix 0
    , decryptOnTick = True
    , location = location
    , key = key
    , vaultTraceId = traceId
    }


parameterErrorCmd : List String -> Cmd msg
parameterErrorCmd errors =
    if List.length errors > 0 then
        DTA.sendMessageOut (DTA.ValidationErrors errors)
    else
        Cmd.none


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init { sessionID, auvToken, vaultTraceId } location key =
    let
        model =
            initModel sessionID auvToken location key vaultTraceId

        errCmd =
            model
                |> Helpers.validateCommonParameters
                |> parameterErrorCmd
    in
    ( model, errCmd )



--        onDetokenize model


validateParameters : Model -> List String
validateParameters model =
    let
        tokenErrors =
            if Helpers.isNothingOrEmpty model.auvToken then
                [ "Missing token" ]
            else
                []

        commonValidationErrors =
            Helpers.validateCommonParameters model
    in
    tokenErrors ++ commonValidationErrors


onDetokenize : Model -> ( Model, Cmd Msg )
onDetokenize model =
    let
        updatedModel =
            { model | decryptOnTick = False }

        errCmds =
            model
                |> validateParameters
                |> parameterErrorCmd
    in
    if errCmds /= Cmd.none then
        ( updatedModel, errCmds )
    else
        -- if model.auvToken == Nothing then
        --     ( updatedModel, DTA.sendMessageOut (DTA.LogError "Missing token") )
        -- else if model.sessionID == Nothing then
        --     ( updatedModel, DTA.sendMessageOut (DTA.LogError "Missing session ID") )
        -- else
        let
            contentBody =
                JE.object
                    [ ( "sessionId", JE.string (Maybe.withDefault "" model.sessionID) ) -- TODO: revisit
                    , ( "utcTimestamp"
                      , JE.string
                            (model.currentTime
                                |> Helpers.toSeconds
                                |> String.fromInt
                            )
                      )
                    , ( "token", JE.string (Maybe.withDefault "" model.auvToken) )
                    ]

            body =
                JE.object
                    [ ( "id", JE.int 1 ) -- TODO: Use more appropriate id
                    , ( "method", JE.string "session_decrypt" )
                    , ( "params", JE.list identity [ contentBody ] )
                    ]
                    |> JE.encode 4
                    |> Http.stringBody "application/json"

            headers =
                []
                    ++ (model.vaultTraceId
                            |> Maybe.map
                                (\traceId ->
                                    [ Http.header "X-VAULT-TRACE-UID" traceId ]
                                )
                            |> Maybe.withDefault []
                       )

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
            ( model, onDetokenizeFail (Helpers.httpErrorToString err) )

        Tick newTime ->
            let
                updatedModel =
                    { model | currentTime = newTime }
            in
            if model.decryptOnTick == True then
                onDetokenize updatedModel
            else
                ( updatedModel, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | location = url }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 1000 Tick
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Detokenizer"
    , body =
        [ div [ class "asi-deTokenizerRoot" ]
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
        ]
    }


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
