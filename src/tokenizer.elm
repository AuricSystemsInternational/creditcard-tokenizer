-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


port module Tokenizer exposing (..)

import Auv
import Char exposing (isDigit)
import CreditCardValidator as CCV
import Html exposing (Html, div, span, text, input, img)
import Html.Attributes exposing (class, classList, maxlength, placeholder, type_, alt, src)
import Html.Events exposing (onInput)
import Http
import Json.Encode as JE
import Navigation as Nav
import Regex exposing (regex)
import Time exposing (Time, second)
import TokenizerApi as TA
import Task


type alias Model =
    { ccNumber : CCV.CreditCardNumber
    , ccNumberError : Maybe String
    , ccNumberValid : Bool
    , allowedCardTypes : List CCV.CardType
    , validatedCardType : Maybe CCV.CardType
    , matchedCardTypes : List CCV.CardType -- keeps track of all matched card type as card number is being entered
    , sessionID : Maybe String
    , currentTime : Time
    , initialTime: Time
    , location : Nav.Location
    }


type alias Flags =
    { sessionID : Maybe String
    , cardTypes : Maybe String
    }


type Msg
    = CCNumberInput String
    | Tick Time
    | OnGetCurrentTime Time
    | OnGetInitialTime Time
    | TokenizeResponse (Result Http.Error Auv.TokenizeResponsePayload)
    | ExternalMessage TA.IncomingMessage
    | LogErr String
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
    "Invalid card type."


init : Flags -> Nav.Location -> ( Model, Cmd Msg )
init flags location =
    -- extract from flags
    let
        locFlags =
            flags

        ( sessionID, cardTypes ) =
            parseFlags flags
    in
    ( initModel sessionID cardTypes location, (cmdGetTime OnGetInitialTime))

cmdGetTime: (Time -> msg) -> Cmd msg 
cmdGetTime callback = 
    Task.perform callback Time.now

initModel : Maybe String -> List CCV.CardType -> Nav.Location -> Model
initModel sessionID cardTypes location =
    { ccNumber = ""
    , ccNumberError = Just msgInvalidCCNumber
    , ccNumberValid = False
    , allowedCardTypes = cardTypes
    , validatedCardType = Nothing
    , matchedCardTypes = []
    , sessionID = sessionID
    , currentTime = 0
    , initialTime = 0
    , location = location
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


parseFlags : Flags -> ( Maybe String, List CCV.CardType )
parseFlags { sessionID, cardTypes } =
    let
        -- parse cardTypes
        actualCardTypes =
            case cardTypes of
                Just value ->
                    value |> parseCardTypes

                Nothing ->
                    []
    in
    ( sessionID, actualCardTypes )


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

validatedCardTypes: CCV.ValidationResult -> List CCV.CardType
validatedCardTypes result = 
    result.card_types 
    |> List.filterMap 
        (\cardTypeInfo ->
            case cardTypeInfo of 
                Nothing -> Nothing   
                Just a -> Just a.cardType
        )

onCCNumberInput : Model -> String -> ( Model, Cmd Msg )
onCCNumberInput model ccNum =
    let
        filteredNumber =
            ccNum
                |> Regex.replace Regex.All (regex "[^0-9 -]+") (always "")

        cleanedNumber =
            filteredNumber
                |> CCV.toCleanCCNumber

        -- Just ensure CC number contains all digits
        validCleanedNumber =
            cleanedNumber
                |> String.all Char.isDigit

        -- results of BIN and LUHN validation
        validationResult =
            CCV.validate ccNum model.allowedCardTypes

        cardType =
            validatedCardType validationResult
        
        allValidCardTypes = 
            validatedCardTypes validationResult

        numValid =
            validationResult.valid

        err =
            if String.isEmpty filteredNumber then
                Just msgInvalidCCNumber
            else if validationResult.cardTypeValid == False then
                Just msgInvalidCCType
            else if numValid == False then
                Just msgInvalidCCNumber
            else
                Nothing

        updatedModel =
            { model | ccNumber = filteredNumber, ccNumberValid = numValid, ccNumberError = err, validatedCardType = cardType
                , matchedCardTypes = allValidCardTypes }
    in
    ( updatedModel, Cmd.none )


isNothing : Maybe a -> Bool
isNothing b =
    case b of
        Nothing ->
            True

        Just _ ->
            False

cmdTimeOut: Cmd msg
cmdTimeOut =                 
    TA.sendMessageOut TA.Auv_Timeout


onCurrentTime: Time -> Model -> (Model, Cmd Msg)
onCurrentTime newTime model = 
    let
        timeup = 
            (sessionActiveFor model) > secondsValidFor

        cmd =
            if timeup then
                cmdTimeOut
            else
                Cmd.none
    in
    ( { model | currentTime = newTime}, cmd )

sessionActiveFor : Model -> Int 
sessionActiveFor model = 
    Time.inSeconds (model.currentTime - model.initialTime) 
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
                            (sessionActiveFor model) > secondsValidFor
                    in
                    if timeup then
                        ( model, cmdTimeOut)
                    else if isCreditCardValid model then
                        onTokenize model
                    else
                        ( model, TA.sendMessageOut (TA.LogError "Invalid credit card") )

                TA.IsCreditCardValid requestId ->
                    ( model, onIsCreditCardValid model requestId )

        CCNumberInput ccNum ->
            onCCNumberInput model ccNum

        Tick newTime ->
            (model, cmdGetTime OnGetCurrentTime)

        TokenizeResponse (Ok payload) ->
            ( model, onTokenizeResponseSuccess model payload )

        TokenizeResponse (Err err) ->
            ( model, onTokenizeFail (toString err) )
        
        OnGetInitialTime time ->
            ({ model | initialTime = time}, Cmd.none)

        OnGetCurrentTime time ->
            model 
            |> onCurrentTime time



        NoOp ->
            ( model, Cmd.none )


onTokenize : Model -> ( Model, Cmd Msg )
onTokenize model =
    --  credit card info should be valid by now
    let
        contentBody =
            JE.object
                [ ( "sessionId", JE.string (Maybe.withDefault "" model.sessionID) )
                , ( "utcTimestamp", JE.string (toString model.currentTime) )
                , ( "plaintextValue", JE.string (CCV.toCleanCCNumber model.ccNumber) )
                ]

        body =
            JE.object
                [ ( "id", JE.int 1 ) -- no need to identify by specific transaction id
                , ( "method", JE.string "session_encrypt" )
                , ( "params", JE.list [ contentBody ] )
                ]
                |> JE.encode 4
                |> Http.stringBody "application/json"

        headers =
            []

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


view : Model -> Html Msg
view model =
    div [ class "asi-tokenizerRoot" ]
        [ viewCCNumber model
        ]


viewTimer : Model -> Html Msg
viewTimer model =
    let
        timerMsg =
            " seconds remain."
        activeFor = sessionActiveFor model
        remaining = secondsValidFor - activeFor         
    in
    div [ class "asi-tokenizerTimer" ]
        [ span []
            [ if remaining <= 0 then
                text ("0" ++ timerMsg)
              else if remaining <= showCounterAt then
                text (toString remaining ++ timerMsg)
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
        [ alt altText, src ("images/creditcards/" ++ fileName)
        , classList 
            [ ("asi-ccImage", True)
            , ("asi-ccImage-disabled", disabled)
            ]
        ]
        []
        

{-| Displays icons for all matched cards
-}
viewCCIcons: List CCV.CardType -> List CCV.CardType -> Html msg
viewCCIcons cardTypes matched =
    div [class "asi-ccImages"]
        (cardTypes 
            |> List.map 
                (\cardType ->
                    let
                        disable = not (List.member cardType matched)                        
                    in
                    case cardType of 
                        CCV.AM -> ccImage "amex.png" "AMEX" disable
                        CCV.DS -> ccImage "discover.png" "Discover" disable
                        CCV.MC -> ccImage "mastercard.png" "MasterCard" disable
                        CCV.VI -> ccImage "visa.png" "Visa" disable
                        CCV.DC -> ccImage "diners.png" "Diners" disable
                        CCV.UK -> ccImage "credit.png" "Unknown" disable                    
                )
        )

        
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every Time.second Tick
        , TA.getIncomingMessage ExternalMessage LogErr
        ]


locationToMsg : Nav.Location -> Msg
locationToMsg location =
    -- no need to do anything
    NoOp


main : Program Flags Model Msg
main =
    Nav.programWithFlags locationToMsg
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
