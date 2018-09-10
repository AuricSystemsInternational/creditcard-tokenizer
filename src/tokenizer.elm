-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


port module Tokenizer exposing (main)

import Auv
import Browser
import Browser.Navigation as Nav
import Char exposing (isDigit)
import CreditCardValidator as CCV
import Html exposing (Html, div, img, input, span, text)
import Html.Attributes exposing (alt, class, classList, maxlength, placeholder, src, type_)
import Html.Events exposing (onInput)
import Http
import Json.Encode as JE
import Regex
import Task
import Time exposing (Month(..), Posix)
import TokenizerApi as TA
import Url


type alias Model =
    { ccNumber : CCV.CreditCardNumber
    , ccNumberError : Maybe String
    , ccNumberValid : Bool
    , allowedCardTypes : List CCV.CardType
    , validatedCardType : Maybe CCV.CardType
    , matchedCardTypes : List CCV.CardType -- keeps track of all matched card type as card number is being entered
    , sessionID : Maybe String
    , currentTime : Posix
    , initialTime : Posix
    , location : Url.Url
    , key : Nav.Key
    , vaultTraceId : Maybe String
    }


type alias Flags =
    { sessionID : Maybe String
    , cardTypes : Maybe String
    , vaultTraceId : Maybe String
    }


type Msg
    = CCNumberInput String
    | Tick Posix
    | OnGetCurrentTime Posix
    | OnGetInitialTime Posix
    | TokenizeResponse (Result Http.Error Auv.TokenizeResponsePayload)
    | ExternalMessage TA.IncomingMessage
    | LogErr String
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOp


secondsValidFor : Int
secondsValidFor =
    -- 9 minutes
    9 * 60


showCounterAt : Int
showCounterAt =
    60


msgInvalidCCNumber : String
msgInvalidCCNumber =
    "Required: (Must be a valid card number.)"


msgInvalidCCType : String
msgInvalidCCType =
    "We do not accept this card brand."


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags location key =
    -- extract from flags
    let
        locFlags =
            flags

        ( sessionID, cardTypes, traceId ) =
            parseFlags flags
    in
    ( initModel sessionID cardTypes location key traceId
    , cmdGetTime OnGetInitialTime
    )


cmdGetTime : (Posix -> msg) -> Cmd msg
cmdGetTime callback =
    Task.perform callback Time.now


initModel : Maybe String -> List CCV.CardType -> Url.Url -> Nav.Key -> Maybe String -> Model
initModel sessionID cardTypes location key traceId =
    { ccNumber = ""
    , ccNumberError = Just msgInvalidCCNumber
    , ccNumberValid = False
    , allowedCardTypes = cardTypes
    , validatedCardType = Nothing
    , matchedCardTypes = []
    , sessionID = sessionID
    , currentTime = Time.millisToPosix 0
    , initialTime = Time.millisToPosix 0
    , location = location
    , key = key
    , vaultTraceId = traceId
    }


parseCardTypes : String -> List CCV.CardType
parseCardTypes str =
    let
        cardTypes =
            str
                |> String.split ","
                |> List.map
                    (\strCard ->
                        case String.trim strCard of
                            "AM" ->
                                CCV.AM

                            "DS" ->
                                CCV.DS

                            "MC" ->
                                CCV.MC

                            "VI" ->
                                CCV.VI

                            _ ->
                                CCV.UK
                    )
    in
    cardTypes


parseFlags : Flags -> ( Maybe String, List CCV.CardType, Maybe String )
parseFlags { sessionID, cardTypes, vaultTraceId } =
    let
        -- parse cardTypes
        actualCardTypes =
            case cardTypes of
                Just value ->
                    value |> parseCardTypes

                Nothing ->
                    []
    in
    ( sessionID, actualCardTypes, vaultTraceId )


onIsCreditCardValid : Model -> String -> Cmd msg
onIsCreditCardValid model requestId =
    let
        valid =
            isCreditCardValid model
    in
    TA.sendMessageOut (TA.CreditCardValid requestId valid)


validatedCardType : CCV.ValidationResult -> Maybe CCV.CardType
validatedCardType result =
    -- ValidationResult may or may not have a card type info. Extracts card type if cardtypeinfo is available
    let
        cardTypeInfo =
            result.card_types
                |> List.head

        cardType =
            case cardTypeInfo of
                Nothing ->
                    Nothing

                Just a ->
                    case a of
                        Nothing ->
                            Nothing

                        Just b ->
                            Just b.cardType
    in
    cardType


validatedCardTypes : CCV.ValidationResult -> List CCV.CardType
validatedCardTypes result =
    result.card_types
        |> List.filterMap
            (\cardTypeInfo ->
                case cardTypeInfo of
                    Nothing ->
                        Nothing

                    Just a ->
                        Just a.cardType
            )


onCCNumberInput : Model -> String -> ( Model, Cmd Msg )
onCCNumberInput model ccNum =
    let
        filteredNumber =
            ccNum
                |> Regex.replace (Maybe.withDefault Regex.never <| Regex.fromString "[^0-9 -]+") (always "")

        cleanedNumber =
            filteredNumber
                |> CCV.toCleanCCNumber

        -- results of BIN and LUHN validation
        validationResult =
            CCV.validate ccNum model.allowedCardTypes

        -- validation result used after at least 4 valid characters entered
        ( ( cardType, allValidCardTypes ), numValid, err ) =
            if String.length cleanedNumber >= 4 then
                let
                    cardType0 =
                        validatedCardType validationResult

                    allValidCardTypes0 =
                        validatedCardTypes validationResult

                    numValid0 =
                        validationResult.valid

                    err0 =
                        if String.isEmpty filteredNumber then
                            Just msgInvalidCCNumber
                        else if validationResult.cardTypeValid == False then
                            Just msgInvalidCCType
                        else if numValid0 == False then
                            Just msgInvalidCCNumber
                        else
                            Nothing
                in
                ( ( cardType0, allValidCardTypes0 ), numValid0, err0 )
            else
                ( ( Nothing, [] ), False, Just msgInvalidCCNumber )

        updatedModel =
            { model
                | ccNumber = filteredNumber
                , ccNumberValid = numValid
                , ccNumberError = err
                , validatedCardType = cardType
                , matchedCardTypes = allValidCardTypes
            }
    in
    ( updatedModel, Cmd.none )


isNothing : Maybe a -> Bool
isNothing b =
    case b of
        Nothing ->
            True

        Just _ ->
            False


cmdTimeOut : Cmd msg
cmdTimeOut =
    TA.sendMessageOut TA.Auv_Timeout


onCurrentTime : Posix -> Model -> ( Model, Cmd Msg )
onCurrentTime newTime model =
    let
        timeup =
            sessionActiveFor model > secondsValidFor

        cmd =
            if timeup then
                cmdTimeOut
            else
                Cmd.none
    in
    ( { model | currentTime = newTime }, cmd )


sessionActiveFor : Model -> Int
sessionActiveFor model =
    let
        totalMilliSeconds =
            (Time.posixToMillis model.currentTime - Time.posixToMillis model.initialTime)
                |> toFloat
    in
    totalMilliSeconds
        / 1000
        |> round


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LogErr err ->
            ( model, TA.sendMessageOut (TA.LogError err) )

        ExternalMessage incomingMsg ->
            case incomingMsg of
                TA.Tokenize ->
                    let
                        timeup =
                            sessionActiveFor model > secondsValidFor
                    in
                    if timeup then
                        ( model, cmdTimeOut )
                    else if isCreditCardValid model then
                        onTokenize model
                    else
                        ( model, TA.sendMessageOut (TA.LogError "Invalid credit card") )

                TA.IsCreditCardValid requestId ->
                    ( model, onIsCreditCardValid model requestId )

        CCNumberInput ccNum ->
            onCCNumberInput model ccNum

        Tick newTime ->
            ( model, cmdGetTime OnGetCurrentTime )

        TokenizeResponse (Ok payload) ->
            ( model, onTokenizeResponseSuccess model payload )

        TokenizeResponse (Err err) ->
            ( model, onTokenizeFail (Auv.httpErrorToString err) )

        OnGetInitialTime time ->
            ( { model | initialTime = time }, Cmd.none )

        OnGetCurrentTime time ->
            model
                |> onCurrentTime time

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


onTokenize : Model -> ( Model, Cmd Msg )
onTokenize model =
    --  credit card info should be valid by now
    let
        contentBody =
            JE.object
                [ ( "sessionId", JE.string (Maybe.withDefault "" model.sessionID) )
                , ( "utcTimestamp", JE.string (model.currentTime |> Auv.toSeconds |> String.fromInt) )
                , ( "plaintextValue", JE.string (CCV.toCleanCCNumber model.ccNumber) )
                ]

        body =
            JE.object
                [ ( "id", JE.int 1 ) -- no need to identify by specific transaction id
                , ( "method", JE.string "session_encrypt" )
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
            Auv.tokenizeResponsePayloadDecoder

        url =
            Auv.vault_url model.location

        request =
            Auv.post url headers body decoder

        cmd =
            Http.send TokenizeResponse request
    in
    ( model, cmd )



{- Generates custom request with timeout info -}


onTokenizeResponseSuccess : Model -> Auv.TokenizeResponsePayload -> Cmd msg
onTokenizeResponseSuccess model payload =
    let
        pl =
            payload

        token =
            payload.result.token

        possibleError =
            payload.error

        requestFailed =
            payload.result.lastActionSucceeded /= 1

        cardType =
            case model.validatedCardType of
                Nothing ->
                    CCV.UK

                Just a ->
                    a
    in
    if requestFailed then
        onTokenizeFail possibleError
    else
        TA.sendMessageOut (TA.Auv_OK token cardType)


onTokenizeFail : String -> Cmd msg
onTokenizeFail err =
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

        -- scrub error codes
        mappedErrorCode =
            mapAuvErrorCode errCode

        -- error message is either the 2nd part of the error or the whole message
        errMessage =
            errCodeMessage
                |> List.tail
                |> Maybe.withDefault []
                |> List.head
                |> Maybe.withDefault ""
    in
    TA.sendMessageOut (TA.Auv_Error mappedErrorCode errMessage)


mapAuvErrorCode : String -> String
mapAuvErrorCode raw =
    let
        trimmed =
            raw
                |> String.trim

        mappedCode =
            if String.startsWith "VLT-102" trimmed || String.startsWith "VLT-103" trimmed then
                "001"
            else
                "999"
    in
    mappedCode


{-| Takes into account current number entered, expiry date info entered
,priorDate info (if any) and filter by card (if any)
-}
isCreditCardValid : Model -> Bool
isCreditCardValid model =
    let
        valid =
            model.ccNumberValid
    in
    valid



--VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Tokenizer"
    , body =
        [ div [ class "asi-tokenizerRoot" ]
            [ viewCCNumber model
            ]
        ]
    }


viewTimer : Model -> Html Msg
viewTimer model =
    let
        timerMsg =
            " seconds remain."

        activeFor =
            sessionActiveFor model

        remaining =
            secondsValidFor - activeFor
    in
    div [ class "asi-tokenizerTimer" ]
        [ span []
            [ if remaining <= 0 then
                text ("0" ++ timerMsg)
              else if remaining <= showCounterAt then
                text (String.fromInt remaining ++ timerMsg)
              else
                text ""
            ]
        ]


viewCCNumber : Model -> Html Msg
viewCCNumber model =
    div [ class "asi-field asi-ccNumber" ]
        [ div
            []
            [ viewTimer model
            ]
        , viewCCIcons model.allowedCardTypes model.matchedCardTypes
        , div []
            [ input
                [ type_ "text"
                , onInput CCNumberInput
                , placeholder "Credit Card Number"
                , Html.Attributes.value model.ccNumber
                , Html.Attributes.maxlength 22
                ]
                []
            , div [ class "asi-clear" ] []
            ]
        , div [ class "asi-error" ]
            [ text <|
                if model.ccNumberValid then
                    ""
                else
                    Maybe.withDefault "'" model.ccNumberError
            ]
        ]


ccImage : String -> String -> Bool -> Html msg
ccImage fileName altText disabled =
    img
        [ alt altText
        , src ("images/creditcards/" ++ fileName)
        , classList
            [ ( "asi-ccImage", True )
            , ( "asi-ccImage-disabled", disabled )
            ]
        ]
        []


{-| Displays icons for all matched cards
-}
viewCCIcons : List CCV.CardType -> List CCV.CardType -> Html msg
viewCCIcons cardTypes matched =
    div [ class "asi-ccImages" ]
        (cardTypes
            |> List.map
                (\cardType ->
                    let
                        disable =
                            not (List.member cardType matched)
                    in
                    case cardType of
                        CCV.AM ->
                            ccImage "amex.png" "AMEX" disable

                        CCV.DS ->
                            ccImage "discover.png" "Discover" disable

                        CCV.MC ->
                            ccImage "mastercard.png" "MasterCard" disable

                        CCV.VI ->
                            ccImage "visa.png" "Visa" disable

                        CCV.DC ->
                            ccImage "diners.png" "Diners" disable

                        CCV.UK ->
                            ccImage "credit.png" "Unknown" disable
                )
        )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 1000 Tick
        , TA.getIncomingMessage ExternalMessage LogErr
        ]


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
